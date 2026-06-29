import AppKit
import Metal
import DPFoundation
import DPWindow
import DPRenderer
import DPAsset
import DPAnimation
import DPProfiler

/// Application boots in this order:
///   Logger → Config → Window → Render Surface → Modules → Update Loop
/// Phase 1 keeps that ordering strict. Phase N may insert stages but the relative
/// ordering of upstream items is preserved.
public final class Application: @unchecked Sendable {
    public let logger: Logger
    public let config: DesktopPetConfig
    public let window: Window
    public let renderer: RendererSurface
    public let moduleManager = ModuleManager()
    public let scene: Scene
    public let updateLoop: UpdateLoop
    public let eventLoop: EventLoop
    public let assetLoader: AssetLoader
    public var animator: Animator?

    private var bootTime: CFAbsoluteTime = 0
    public private(set) var didBoot = false
    public static weak var shared: Application?

    public init(configuration: DesktopPetConfig = .default, logger: Logger = .shared) {
        self.logger = logger
        self.config = configuration
        self.window = Window(configuration: Window.Configuration(from: configuration.window))
        self.renderer = Phase1Renderer()
        let assetCache = MemoryCache(capacity: configuration.assets.memoryCacheBytes)
        self.assetLoader = AssetLoader(cache: assetCache, logger: logger)
        self.scene = Scene(renderer: renderer,
                           profiler: Profiler.shared,
                           camera: Camera())
        self.eventLoop = EventLoop()
        self.updateLoop = UpdateLoop { dt in }
        assureAppleSilicon(logger: logger)
        Application.shared = self
        // After all stored properties are initialized, swap in the real closure.
        let box = self
        self.updateLoop.replaceTick { dt in box.tick(dt: dt) }
    }

    /// Public boot path.
    ///
    /// Order is critical (spec-003 §2 + spec-002 risk):
    ///   1. NSApp activation / finished-launching
    ///   2. Window style + frame BEFORE makeKeyAndOrderFront
    ///   3. Renderer view attached → bounce a Metal device
    ///   4. UpdateLoop started so animation is alive on frame 1
    ///   5. eventLoop.run() blocks until Cmd-Q
    public func run() {
        bootTime = CFAbsoluteTimeGetCurrent()
        let ctx = RuntimeContext(config: config, logger: logger)

        // (1) Activation
        eventLoop.prepare()

        // (2) Synchronous preload of the fox model — spec-005 acceptance wants determinism.
        do {
            try moduleManager.register(RenderMeshModule(passGraph: renderer.passGraph))
            try moduleManager.register(AssetPreloadModule(url: URL(fileURLWithPath: config.assets.foxGLBPath),
                                                          loader: assetLoader,
                                                          scene: scene,
                                                          application: self))
            try moduleManager.bootAll(ctx: ctx)
        } catch {
            logger.error("boot failure: \(error)")
            return
        }

        // (3) Attach renderer view to the window.
        let scale = window.attach(rendererView: renderer.hostView)
        if let device = MTLCreateSystemDefaultDevice() {
            renderer.prepare(device: device, scaleFactor: scale)
        } else {
            logger.warn("no Metal device available — running with software fallback")
        }

        renderer.passGraph.counterSink = { name, value in
            Profiler.shared.record(DPProfiler.Counter(name: name, value: value))
        }

        // (4) Start the frame loop.
        updateLoop.start()
        didBoot = true
        logger.info("Application boot took \(Int((CFAbsoluteTimeGetCurrent() - bootTime) * 1000))ms")
        logger.info("Expected behavior:")
        logger.info("  • a 320×320 desktop overlay appears centered (or at config.position)")
        logger.info("  • the overlay sits ABOVE other windows (always-on-top)")
        logger.info("  • clicks fall THROUGH to the underlying app")
        logger.info("  • a single colored background (Phase 1 placeholder, no fox mesh yet)")
        logger.info("  • Cmd-Q quits cleanly within ~200ms")

        // Install Cmd-Q bridge. Phase 9 swaps this for a real NSApplicationDelegate;
        // for now we just listen for willTerminate so shutdown() runs even without UI.
        installTerminateBridge()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.shutdown() }

        // (5) Block forever.
        eventLoop.run()
    }

    /// Hook `NSApplicationDelegate.applicationShouldTerminate` to drive
    /// `ShutdownCoordinator` on Cmd-Q. Failure to install means Cmd-Q would be
    // silently swallowed; instead, we just install a minimal closure-based delegate.
    private func installTerminateBridge() {
        // ponytail: capture via unowned Bridge-style retain — the bridge is held alive
        // by `_terminateBridgeHolder` for the lifetime of the Application instance.
        let weakBridge = WeakBridgeBox(self)
        let delegate = TerminableDelegate(onTerminate: { [weak weakBridge] in
            guard let bridge = weakBridge?.value else { return }
            bridge.coordinateShutdown()
        })
        _terminateBridgeHolder = delegate
        if NSApplication.shared.delegate == nil {
            NSApplication.shared.delegate = delegate
        } else {
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak weakBridge] _ in
                weakBridge?.value?.coordinateShutdown()
            }
        }
    }

    /// Coordinate stack so the terminate bridge can drive shutdown via a single typed
    /// method. Ponytail: this indirection costs a heap allocation; Phase 8 moves to
    /// an NSApplicationDelegate subclass and removes this box.
    fileprivate func coordinateShutdown() { shutdown() }

    private final class WeakBridgeBox {
        weak var value: Application?
        init(_ value: Application) { self.value = value }
    }

    private var _terminateBridgeHolder: AnyObject?

    /// Per-frame tick: animator first (Phase 5 pulls in driver hooks), then modules → render.
    private func tick(dt: Double) {
        let ctx = RuntimeContext(config: config, logger: logger)
        animator?.tick(dt: dt)
        scene.animationState.update(pipeline: scene.skinningPipeline)
        moduleManager.tickAll(ctx: ctx, dt: dt)
        Profiler.shared.tick(dt: dt, gpuMs: 0, cpuMs: 0, currentFramebufferDrop: 0)
    }

    /// Public so Cmd-Q handlers and tests can compose ShutdownCoordinator.
    public func shutdown() {
        let ctx = RuntimeContext(config: config, logger: logger)
        let coord = ShutdownCoordinator(moduleOrder: moduleManager.ordering())
        coord.run(manager: moduleManager, scene: scene, ctx: ctx)
        updateLoop.stop()
        window.detach()
    }

    /// Apple Silicon guard per spec-002 risk table.
    private func assureAppleSilicon(logger: Logger) {
        #if arch(arm64)
        // Good — Apple Silicon.
        #else
        logger.error("DesktopPet requires Apple Silicon; Intel Macs are not supported in Phase 1.")
        #endif
    }
}

/// Minimal NSApplicationDelegate shim. Conforms to `NSApplicationDelegate` via
/// Objective-C runtime — Phase 8 will replace with a real class.
final class TerminableDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let onTerminate: () -> Void
    init(onTerminate: @escaping () -> Void) {
        self.onTerminate = onTerminate
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        onTerminate()
        // Confirm shutdown so the app exits cleanly. `.terminateNow` is the modern
        // preference; `.terminateCancel` would abort Cmd-Q, which we don't want.
        return .terminateNow
    }
}

// MARK: - Phase 1 Modules

/// RenderMeshModule — registers the default root ClearPass during the module-boot
/// window (Phase 2 spec-001). Real PBR passes land in spec-002+.
final class RenderMeshModule: RuntimeModule {
    let name = "RenderMesh"
    let dependencies: [String] = []
    private let passGraph: DPRenderer.Renderer
    init(passGraph: DPRenderer.Renderer) { self.passGraph = passGraph }
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {
        // Phase 2 spec-001: register the default root ClearPass during the
        // module-boot window (registration is illegal after the first tick).
        try? passGraph.registerPass(DPRenderer.ClearPass(), context: ())
    }
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}

/// Synchronously loads `fox.glb` at boot. Spec-004 acceptance: load fox.glb cold ≤150ms.
final class AssetPreloadModule: RuntimeModule {
    let name: String
    let dependencies: [String]
    private let url: URL
    private let loader: AssetLoader
    private let scene: Scene
    private weak var application: Application?

    init(url: URL, loader: AssetLoader, scene: Scene, application: Application?) {
        self.url = url
        self.loader = loader
        self.scene = scene
        self.application = application
        self.name = "AssetPreload-\(url.lastPathComponent)"
        self.dependencies = ["RenderMesh"]
    }

    func moduleWillBoot(_ ctx: RuntimeContext) {}

    func moduleDidBoot(_ ctx: RuntimeContext) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) { [self] in
            defer { semaphore.signal() }
            do {
                let asset = try await loader.load(url, type: .glb)
                if case let .glb(glbAsset) = asset {
                    let key = (try? AssetKeyBuilder.sha256(of: url)) ?? AssetKey(hash: "fox")
                    scene.assetRegistry.register(.glb(glbAsset), key: key)
                    let skeleton = Skeleton.fromSkeletonData(glbAsset.skeleton)
                    let animator = Animator(skeleton: skeleton)
                    if let firstAnimData = glbAsset.animations.first {
                        let clip = convertClip(firstAnimData)
                        animator.attach(clip)
                    }
                    scene.animationState.setAnimator(animator)
                    application?.animator = animator
                    _ = scene.skinningPipeline.upload(mesh: glbAsset.mesh)
                    ctx.logger.info("loaded fox.glb bones=\(glbAsset.skeleton.bones.count) animFrames=\(glbAsset.animations.first?.channels.first?.keyframes.count ?? 0)")
                }
            } catch {
                ctx.logger.error("fox.glb preload failed: \(error)")
            }
        }
        // ponytail: a sync wait is fine in Phase 1 because spec-004 insists cold load ≤ 150ms.
        // Phase 4 swaps to fire-and-forget once the renderer surfaces a real "asset-ready" event.
        if semaphore.wait(timeout: .now() + .milliseconds(500)) == .timedOut {
            ctx.logger.warn("fox.glb preload exceeded 500ms; continuing asynchronously")
        }
    }

    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}

    /// Convert a `DPAsset.AnimationData` into the higher-level `DPAnimation.AnimationClip`.
    /// Phase 1 keeps this strict; spec-005 acceptance asserts round-trip equality.
    private func convertClip(_ data: DPAsset.AnimationData) -> AnimationClip {
        let channels: [AnimationClip_Channel] = data.channels.compactMap { chan -> AnimationClip_Channel? in
            guard chan.boneIndex >= 0 else { return nil }
            // Build the DPAnimation.Keyframe → Value mapping.
            let mappedKf: [AnimationClip_Keyframe] = chan.keyframes.map { kf in
                let val: AnimationClip_Value = {
                    switch kf.value {
                    case let .translate(v): return .translate(v)
                    case let .rotate(q):    return .rotate(q)
                    case let .scale(v):     return .scale(v)
                    }
                }()
                return AnimationClip_Keyframe(time: kf.time, value: val)
            }
            let property: AnimationClip_Channel.Property
            switch chan.property.canonical() {
            case .translate: property = .translate
            case .rotate:    property = .rotate
            case .scale:     property = .scale
            }
            return AnimationClip_Channel(boneIndex: chan.boneIndex, property: property, keyframes: mappedKf)
        }
        return AnimationClip(name: data.name, duration: data.duration, channels: channels, looping: data.looping)
    }
}

/// Type-aliases so the runtime-side converter is concrete and readable. The Application
/// is the single hoist point to keep the asset→animation conversion typed.
typealias AnimationClip_Channel = DPAnimation.Channel
typealias AnimationClip_Keyframe = DPAnimation.Keyframe
typealias AnimationClip_Value = DPAnimation.Value
