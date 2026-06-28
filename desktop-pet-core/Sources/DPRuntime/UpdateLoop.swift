import Foundation
import AppKit
import DPFoundation
import DPWindow
import DPRenderer
import DPAsset
import DPAnimation
import DPProfiler

/// UpdateLoop drives the per-frame tick. In Phase 1 we ship a deterministic
/// `LoopTester` for unit tests AND a CADisplayLink-backed path for production.
public final class UpdateLoop {
    public typealias TickCallback = (_ dt: Double) -> Void
    private var displayLink: CVDisplayLink?
    private var lastTs: CFAbsoluteTime = 0
    internal var onTick: TickCallback
    private var running = false
    private let lock = NSLock()

    /// The UpdateLoop's overhead ceiling per spec-003 §5 (Performance: ≤80 µs).
    public private(set) var lastOverheadUs: Double = 0

    public init(onTick: @escaping TickCallback) {
        self.onTick = onTick
    }

    /// Replace the tick callback after construction. Used by Application because
    /// the closure must capture self and Swift requires all stored properties be
    /// initialized before that capture is legal.
    public func replaceTick(_ newTick: @escaping TickCallback) {
        self.onTick = newTick
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { return }
        running = true
        lastTs = CFAbsoluteTimeGetCurrent()

        // Build a CVDisplayLink.
        var link: CVDisplayLink?
        let result = CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard result == kCVReturnSuccess, let link = link else {
            // ponytail: fallback to a manual 60Hz loop when DisplayLink can't be created.
            startTimerFallback()
            return
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let me = Unmanaged<UpdateLoop>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { me.tick() }
            return kCVReturnSuccess
        }, userInfo)
        CVDisplayLinkStart(link)
        self.displayLink = link
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
        running = false
    }

    /// Mannual tick — uses real time delta. Useful in unit tests with a controllable clock.
    public func tick() {
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(1.0/240.0, min(0.5, now - lastTs))
        lastTs = now
        let start = CFAbsoluteTimeGetCurrent()
        onTick(dt)
        lastOverheadUs = (CFAbsoluteTimeGetCurrent() - start) * 1_000_000
    }

    private func startTimerFallback() {
        // ponytail: 60Hz timer; only used if DisplayLink creation fails.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.displayLink = nil
        objc_setAssociatedObject(self, &displayLinkFallbackKey, timer, .OBJC_ASSOCIATION_RETAIN)
    }
}

private var displayLinkFallbackKey: UInt8 = 0

/// EventLoop — wraps `NSApplication` event pump.
///
/// SPEC-002 requires the desktop overlay never shows up in the Dock and joins every
/// Space. SPEC-005 acceptance gates Cmd-Q graceful shutdown. We do all wiring in two
/// places: this type owns the policy decisions (`.accessory`, join-all-spaces, etc.);
/// `Application.run()` owns the order of operations so the lifecycle test can
/// intercept.
public final class EventLoop {
    /// The activation policy we want — accessory means the app is in the foreground
    /// (over normal windows) but doesn't show a Dock icon or menu bar. Phase 5 may
    /// flip to `.regular` for the Chat Panel; Phase 1 stays `.accessory`.
    public enum ActivationPolicy {
        case accessory
        case regular
    }

    public let policy: ActivationPolicy

    public init(policy: ActivationPolicy = .accessory) {
        self.policy = policy
    }

    /// Configure the global `NSApplication` for our overlay role. Idempotent —
    /// safe to call twice (test code may want to re-apply).
    public func prepare() {
        let app = NSApplication.shared
        switch policy {
        case .accessory: app.setActivationPolicy(.accessory)
        case .regular:   app.setActivationPolicy(.regular)
        }
        // ponytail: pull the event forward so the overlay key window can accept
        // MouseMoved correctly on first appearance even when the user did not click.
        app.activate(ignoringOtherApps: true)
    }

    /// Block on the run loop. Call *after* `prepare()` and after the Window has
    /// attached + key-ordered. Exit on `Cmd-Q` ⇒ `terminateGracefully()`.
    public func run() {
        NSApplication.shared.run()
    }

    public func terminateGracefully() {
        NSApplication.shared.terminate(nil)
    }
}
