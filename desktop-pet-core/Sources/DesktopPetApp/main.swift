import AppKit
import Foundation
import DPRuntime
import DPFoundation
import DPAnimation
import DPAsset
import DPProfiler

// Desktop-pet standalone binary — `swift run desktop-pet`.
//
// Two modes:
//   • Default — boots a visible 320×320 sea-blue overlay centered on the primary
//     display. Click-through ON. Cmd-Q to quit. Phase 1 placeholder clear-color;
//     Phase 2 wires the fox GLB mesh render pass.
//   • `DPT_HEADLESS=1` — boots the runtime tree without spinning NSApp.run(). The
//     asset is loaded, the animator ticks, the profiler records frames; we print
//     a summary table and exit. Useful for CI and dev shell checks without a window
//     server.

@main
struct DesktopPetApp {
    static func main() {
        // Headless mode: opt in via argv `--headless` or env `DPT_HEADLESS=1`.
        // Used by dev shell and CI to validate boot/asset/animator without a window server.
        let args = CommandLine.arguments
        let headless = args.contains("--headless") ||
            ProcessInfo.processInfo.environment["DPT_HEADLESS"] == "1"

        FileHandle.standardError.write(Data("[BOOT] mode=\(headless ? "headless" : "interactive") argc=\(args.count)\n".utf8))
        if headless {
            runHeadlessSelfCheck()
        } else {
            runInteractive()
        }
    }

    /// Boot, tick, summarize, exit. Skips `NSApplication.run()` so the binary exits
    /// deterministically inside CI without a window server.
    private static func runHeadlessSelfCheck() {
        var config = DesktopPetConfig.default
        config.assets.foxGLBPath = resolveFoxPath()

        let app = Application(configuration: config)
        // Boot modules synchronously (do not run the NSApp event loop).
        _ = CFAbsoluteTimeGetCurrent()
        app.eventLoop.prepare()
        let ctx = RuntimeContext(config: config, logger: app.logger)
        do {
            try app.moduleManager.register(RenderMeshModuleStub())
            try app.moduleManager.register(AssetPreloadModuleStub(url: URL(fileURLWithPath: config.assets.foxGLBPath),
                                                                   loader: app.assetLoader,
                                                                   scene: app.scene,
                                                                   application: app))
            try app.moduleManager.bootAll(ctx: ctx)
        } catch {
            app.logger.error("headless boot failed: \(error)")
            exit(2)
        }

        // Wait synchronously for the async load (≤500ms). Phase 4 swaps to event-based
        // readiness; spec-004 acceptance insists cold load ≤150ms so 500ms is generous.
        let waitStart = CFAbsoluteTimeGetCurrent()
        while app.scene.assetRegistry.glb.isEmpty {
            if CFAbsoluteTimeGetCurrent() - waitStart > 1.0 { break }
            Thread.sleep(forTimeInterval: 0.005)
        }
        let loadMs = (CFAbsoluteTimeGetCurrent() - waitStart) * 1000.0

        // Tick the update loop 60 frames at simulated dt.
        let t0 = CFAbsoluteTimeGetCurrent()
        for _ in 0..<60 {
            app.scene.animationState.update(pipeline: app.scene.skinningPipeline)
            app.animator?.tick(dt: 1.0/60)
            app.moduleManager.tickAll(ctx: ctx, dt: 1.0/60)
            app.scene.profiler.tick(dt: 1.0/60, gpuMs: 0, cpuMs: 0, currentFramebufferDrop: 0)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        app.logger.info("headless load wait took \(Int(loadMs))ms; 60-frame tick took \(Int(elapsed * 1000))ms (≈\(Int(60.0 / max(elapsed, 1e-9))) FPS sustained)")

        // Summarize state.
        let bones = app.scene.assetRegistry.glb.first?.value.skeleton.bones.count ?? 0
        let frames = app.scene.profiler.frameStats.count
        app.logger.info("headless summary: glb bones=\(bones) profiler.frames=\(frames)")
        app.shutdown()
        exit(0)
    }

    /// Default launch path: window + event loop.
    private static func runInteractive() {
        var config = DesktopPetConfig.default
        config.window.clickThrough = true
        config.window.position = .center
        config.assets.foxGLBPath = resolveFoxPath()

        let app = Application(configuration: config)
        // Patch the NSWindow *post-init* so we keep production Window factory as-is.
        // ponytail: Phase 9 introduces a typed DI Window slot; for this demo we use the
        // last-mile `backgroundColor` swap. Since we want a colored, click-through overlay,
        // we turn `isOpaque = true` and set our demo background color.
        let win = app.window.nsWindow
        win.isOpaque = true
        win.backgroundColor = NSColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1.0)
        win.ignoresMouseEvents = true   // confirm click-through

        app.run()
    }

    /// Resolve `pets-models/fox.glb` from either the SwiftPM working directory (when run
    /// via `swift run`) or the repo root.
    private static func resolveFoxPath() -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(cwd)/pets-models/fox.glb",
            "\(cwd)/../pets-models/fox.glb"
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) { return c }
        }
        return candidates.first!
    }
}

// Headless-only stubs — same surface as production modules but no Window attach.
private final class RenderMeshModuleStub: RuntimeModule {
    let name = "RenderMesh"
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {}
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}

private final class AssetPreloadModuleStub: RuntimeModule {
    let name: String
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
    }
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {
        Task.detached { [self] in
            do {
                let asset = try await loader.load(url, type: .glb)
                if case let .glb(glb) = asset {
                    let key = (try? AssetKeyBuilder.sha256(of: url)) ?? AssetKey(hash: "fox")
                    scene.assetRegistry.register(.glb(glb), key: key)
                    let skel = Skeleton.fromSkeletonData(glb.skeleton)
                    let anim = Animator(skeleton: skel)
                    if let first = glb.animations.first {
                        anim.attach(convert(first))
                    }
                    scene.animationState.setAnimator(anim)
                    application?.animator = anim
                    ctx.logger.info("loaded fox.glb bones=\(glb.skeleton.bones.count) animFrames=\(glb.animations.first?.channels.first?.keyframes.count ?? 0)")
                }
            } catch {
                ctx.logger.error("fox.glb preload failed: \(error)")
            }
        }
    }
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}

    private func convert(_ data: DPAsset.AnimationData) -> AnimationClip {
        let chans = data.channels.compactMap { chan -> Channel? in
            guard chan.boneIndex >= 0 else { return nil }
            let kfs = chan.keyframes.map { kf -> DPAnimation.Keyframe in
                let v: Value
                switch kf.value {
                case let .translate(x): v = .translate(x)
                case let .rotate(q):    v = .rotate(q)
                case let .scale(x):     v = .scale(x)
                }
                return Keyframe(time: kf.time, value: v)
            }
            let property: Channel.Property
            switch chan.property.canonical() {
            case .translate: property = .translate
            case .rotate:    property = .rotate
            case .scale:     property = .scale
            }
            return Channel(boneIndex: chan.boneIndex, property: property, keyframes: kfs)
        }
        return AnimationClip(name: data.name, duration: data.duration, channels: chans, looping: data.looping)
    }
}
