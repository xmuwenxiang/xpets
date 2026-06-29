import Foundation
import DPFoundation
import DPWindow
import AppKit
import MetalKit
import Metal

/// Entry point for the renderer. Phase 1's job is *boots and renders one frame*.
public protocol RendererSurface: AnyObject {
    /// The view to plug into the window's content.
    var hostView: NSView { get }

    /// The pass-graph owner (Phase 2). Shells expose their inner Renderer so
    /// modules can register passes during the module-boot window.
    var passGraph: Renderer { get }

    /// Called once after view attachment to set up Metal pipeline objects.
    func prepare(device: MTLDevice, scaleFactor: Double)

    /// Called every frame from the main loop.
    func renderFrame(into view: MTKView, dt: Double)

    /// Tear down on shutdown.
    func shutdown()
}

/// A minimal Phase 1 renderer — keeps `MTKView` live, mocks a clear-color draw call,
/// integrates with the Profiler to publish dt. Phase 2 replaces this with the real pass graph.
public final class Phase1Renderer: NSObject, RendererSurface, MTKViewDelegate {
    public let _mtkView: MTKView
    public var hostView: NSView { _mtkView }
    public private(set) var prepared = false
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    public let passGraph = Renderer(device: nil)
    private var frameCount: Int = 0
    private let onFrameDrawn: ((Double) -> Void)?
    private var lastFrameTimestamp: CFTimeInterval = 0

    public init(onFrameDrawn: ((Double) -> Void)? = nil) {
        self._mtkView = MTKView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        self.onFrameDrawn = onFrameDrawn
        super.init()
        self._mtkView.delegate = self
        self._mtkView.colorPixelFormat = .bgra8Unorm
        self._mtkView.layer?.isOpaque = false
    }

    public func prepare(device: MTLDevice, scaleFactor: Double) {
        if prepared { return }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        passGraph.attach(device: device)
        self._mtkView.device = device
        self._mtkView.framebufferOnly = true
        self._mtkView.colorPixelFormat = .bgra8Unorm
        self._mtkView.layer?.isOpaque = false
        self.prepared = true
        if let scale = NSScreen.main?.backingScaleFactor, scale > 0 {
            self._mtkView.layer?.contentsScale = scale
        } else {
            self._mtkView.layer?.contentsScale = CGFloat(scaleFactor)
        }
    }

    public func renderFrame(into view: MTKView, dt: Double) {
        guard prepared else { return }
        guard let queue = commandQueue,
              let buffer = queue.makeCommandBuffer(),
              let rpd = view.currentRenderPassDescriptor else { return }
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1.0)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: rpd) else { return }
        // Single tick: frameIndex++ + counters + encode registered passes (fox draw).
        passGraph.tick(dt: dt, into: encoder)
        encoder.endEncoding()
        if let drawable = view.currentDrawable { buffer.present(drawable) }
        buffer.addCompletedHandler { _ in }
        buffer.commit()
        frameCount += 1
    }

    public func shutdown() {
        commandQueue = nil
        device = nil
        prepared = false
    }

    // MARK: - MTKViewDelegate
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op for Phase 1; resize policy is intrinsic.
    }

    public func draw(in view: MTKView) {
        let now = CFAbsoluteTimeGetCurrent()
        let dt: Double
        if lastFrameTimestamp == 0 {
            dt = 1.0 / 60.0
        } else {
            // Clamp dt into spec-003 acceptance band [1/240, 1/30] s so frame-rate
            // floods (or screen-unlock stalls) do not break UpdateLoop invariants.
            let raw = now - lastFrameTimestamp
            dt = min(1.0 / 30.0, max(1.0 / 240.0, raw))
        }
        lastFrameTimestamp = now
        renderFrame(into: view, dt: dt)
        onFrameDrawn?(dt)
    }
}

/// Mock surface used in tests. Holds no Metal device; tracks frame counts so
/// integration tests can assert per-tick render call counts.
public final class RendererMock: RendererSurface {
    public let hostView: NSView
    public let passGraph = Renderer(device: nil)   // headless, for Application/Scene tests
    public private(set) var framesRendered = 0
    public var scaleFactorOnPrepare: Double = 1.0

    public init() {
        self.hostView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
    }

    public func prepare(device: MTLDevice, scaleFactor: Double) {
        self.scaleFactorOnPrepare = scaleFactor
    }

    public func renderFrame(into view: MTKView, dt: Double) {
        framesRendered += 1
    }

    public func shutdown() {
        framesRendered = 0
    }
}

// MARK: - Phase 2 Pass Graph

public enum RendererError: Error, Equatable {
    case alreadyRunning
    case duplicatePassID(RenderPassId)
}

/// Production renderer entry path. Owns the ordered pass list, the per-frame
/// index, and (when a device is attached) the Metal command queue. Constructible
/// without an MTLDevice for headless CI logic tests.
public final class Renderer: @unchecked Sendable {
    private let device: MTLDevice?
    private var commandQueue: MTLCommandQueue?

    public private(set) var currentFrameIndex: UInt64 = 0
    public private(set) var isRunning = false

    private var passes: [AnyRenderPass] = []
    private var pendingRemovals: Set<RenderPassId> = []
    private var pendingDrops: Set<RenderPassId> = []

    /// Snapshot of registered pass IDs in stable execution order.
    public var registeredPassIDs: [RenderPassId] { passes.map { $0.id } }

    /// Injected counter sink. The Runtime wires this to `Profiler.shared.record`
    /// (Renderer cannot import DPProfiler — DPProfiler already depends on
    /// DPRenderer, so a direct call would be a circular dependency).
    public var counterSink: ((String, Double) -> Void)?

    public init(device: MTLDevice? = nil) {
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
    }

    /// Attach a real device post-init (used by Phase1Renderer.prepare, which runs
    /// after module-boot). No-op once the Renderer has started ticking.
    public func attach(device: MTLDevice) {
        guard !isRunning else { return }
        self.commandQueue = device.makeCommandQueue()
    }

    /// Register a pass. Only legal before the first tick (module-boot window).
    /// `after` anchors insertion immediately after the named pass; nil appends.
    public func registerPass<P: RenderPass>(
        _ pass: P,
        context: P.Context,
        after anchor: RenderPassId? = nil
    ) throws {
        guard !isRunning else { throw RendererError.alreadyRunning }
        let id = pass.id
        guard !passes.contains(where: { $0.id == id }) else {
            throw RendererError.duplicatePassID(id)
        }
        let box = AnyRenderPass(pass, context: context)
        if let anchor, let idx = passes.firstIndex(where: { $0.id == anchor }) {
            passes.insert(box, at: idx + 1)
        } else {
            passes.append(box)
        }
    }

    /// Schedule removal; the box is released on the next tick (present-tick drain)
    /// so no use-after-free mid-frame.
    public func unregisterPass(id: RenderPassId) {
        pendingRemovals.insert(id)
    }

    /// Advance one frame. Increments currentFrameIndex, flips isRunning, drains
    /// pending removals, encodes passes into `encoder` if provided, emits
    /// a Counter per pass via `counterSink`, and drops any pass that threw.
    public func tick(dt: Double, into encoder: MTLRenderCommandEncoder? = nil) {
        if !pendingRemovals.isEmpty {
            passes.removeAll { pendingRemovals.contains($0.id) }
            pendingRemovals.removeAll()
        }
        currentFrameIndex &+= 1
        isRunning = true
        for box in passes {
            if let enc = encoder {
                do { _ = try box.encode(into: enc) }
                catch { pendingDrops.insert(box.id) }
            }
            counterSink?(box.gpuLabel, 0)
        }
        if !pendingDrops.isEmpty {
            passes.removeAll { pendingDrops.contains($0.id) }
            pendingDrops.removeAll()
        }
    }
}
