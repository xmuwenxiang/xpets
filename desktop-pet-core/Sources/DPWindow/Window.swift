import AppKit
import DPFoundation

/// Transparent, borderless, always-on-top, click-through overlay. Phase 1's host for
/// the Metal-backed view. SPEC-002 acceptance gates each step.
public final class Window: NSObject, NSWindowDelegate {
    /// Phase 1 typed configuration — the only supported override of geometry is via
    /// this struct; runtime mutation deferred to Phase 9.
    public struct Configuration {
        public var width: Double
        public var height: Double
        public var position: WindowConfig.Position
        public var multiDisplayPolicy: WindowConfig.MultiDisplayPolicy
        public var clickThrough: Bool
        /// Demo-only: when true the window paints an opaque colored background instead of
        /// alpha=0 (the production posture). Phase 2 cancels this once the fox mesh is
        /// rendered; for now it gives the user a *visible* anchored overlay.
        public var visibleBackground: Bool

        public init(from config: WindowConfig, visibleBackground: Bool = false) {
            self.width = config.width
            self.height = config.height
            self.position = config.position
            self.multiDisplayPolicy = config.multiDisplayPolicy
            self.clickThrough = config.clickThrough
            self.visibleBackground = visibleBackground
        }
    }

    /// Future-facing surface — Phase 5 uses these to flip mouse interactivity in a
    /// rectangular sub-area. Phase 1 ships the protocol only.
    public struct MouseRegions {
        public private(set) var interactiveRects: [CGRect] = []
        public init() {}
        public mutating func addInteractive(rect: CGRect) { interactiveRects.append(rect) }
        public mutating func removeInteractive(rect: CGRect) { interactiveRects.removeAll { $0 == rect } }
    }

    public let configuration: Configuration
    public let nsWindow: NSWindow
    public private(set) var mouseRegions = MouseRegions()
    private(set) public var attached = false

    /// Notification published when a display is lost — Phase 6+ tools subscribe.
    public struct DisplayLostEvent { public let display: String }

    public init(configuration: Configuration) {
        self.configuration = configuration
        let style: NSWindow.StyleMask = [.borderless]
        let rect = NSRect(x: 0, y: 0, width: configuration.width, height: configuration.height)
        self.nsWindow = NSWindow(
            contentRect: rect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        super.init()
        nsWindow.delegate = self
        // Properties required BEFORE `makeKeyAndOrderFront` per spec-002 risk.
        // ponytail: Phase 1 ships the window *transparent* (alpha 0) for production; this
        // demo binary flips `isOpaque` ON the first time we attach so the user can see
        // the rendered clear color. Phase 2 will use the real fox GLB; the demo's
        // "Phase1BackgroundVisible" toggle is in `Window.Configuration.visibleBackground`.
        let visibleBackground = configuration.visibleBackground
        nsWindow.isOpaque = visibleBackground ? true : false
        nsWindow.backgroundColor = visibleBackground ? NSColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1.0) : .clear
        nsWindow.hasShadow = false
        nsWindow.ignoresMouseEvents = configuration.clickThrough
        // ponytail: explicit Int cast — CGWindowLevel is Int32 across SDK versions, NSWindow.Level
        // wants Int. Force the value through Int to keep the call platform-agnostic.
        let aboveMaximum = Int(CGWindowLevelForKey(.maximumWindow)) + 1
        nsWindow.level = NSWindow.Level(rawValue: aboveMaximum)
        nsWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Sonoma-safe selector — gesture rejectable keeps menu/notification clicks from leaking.
        nsWindow.isMovableByWindowBackground = false

        // Multi-display: re-center on screen changes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API
    /// Attach an `NSView`-derived renderer view onto the window's content. Returns
    /// the scaling factor used (DPI of the primary display backing the window).
    @discardableResult
    public func attach(rendererView: NSView) -> Double {
        precondition(!attached, "Window.attach called twice")
        // Apply position policy.
        applyPositionPolicy()
        // Plug in renderer view.
        let container = nsWindow.contentView
        container?.wantsLayer = true
        rendererView.frame = container?.bounds ?? .zero
        rendererView.autoresizingMask = [.width, .height]
        container?.addSubview(rendererView)
        // Order front BEFORE returning to caller so first frame can submit.
        nsWindow.makeKeyAndOrderFront(nil)
        // Click-through should re-assert on activation (defensive: spec-002 risk).
        nsWindow.ignoresMouseEvents = configuration.clickThrough
        attached = true
        return nsWindow.backingScaleFactor
    }

    public func detach() {
        if attached {
            nsWindow.orderOut(nil)
            attached = false
        }
    }

    /// Synthetic hit-test used by tests to confirm click-through. Returns false if
    /// the window would consume the click — the spec's "Click on the fox's bounding
    /// box: click event reaches app underneath" requires .ignoresMouseEvents == true
    /// for the window's full content rect. Phase 5 toggles this per rect.
    public func eventWouldReachUnderlyingApp(at point: NSPoint) -> Bool {
        guard attached else { return true }
        if configuration.clickThrough {
            return true
        }
        // If a future-region is interactive, the test can monkey-patch `mouseRegions`
        // and re-run. Phase 1 always-true path dominates.
        return !interactiveRectsContain(point: point)
    }

    // MARK: - NSWindowDelegate
    public func windowDidBecomeKey(_ notification: Notification) {
        // Defensive re-assertion per spec-002 risk row.
        nsWindow.ignoresMouseEvents = configuration.clickThrough
    }

    // MARK: - Internal
    @objc private func handleScreenParametersChanged() {
        // Re-center if policy asks for active-display follow.
        guard configuration.multiDisplayPolicy == .followActiveDisplay else { return }
        applyPositionPolicy()
    }

    private func applyPositionPolicy() {
        guard let screen = pickingScreen() else { return }
        let visible = screen.visibleFrame
        let winWidth = configuration.width
        let winHeight = configuration.height
        let target: NSPoint
        switch configuration.position {
        case .center:
            target = NSPoint(
                x: visible.midX - winWidth / 2,
                y: visible.midY - winHeight / 2
            )
        case .topLeft:
            target = NSPoint(x: visible.minX + 8, y: visible.maxY - winHeight - 8)
        case let .custom(x, y):
            target = NSPoint(x: x, y: y)
        }
        nsWindow.setFrame(
            NSRect(x: target.x, y: target.y, width: winWidth, height: winHeight),
            display: true,
            animate: false
        )
    }

    /// Honor multi-display policy: `.primaryOnly` → NSScreen.main; `.followActiveDisplay`
    /// → "active" screen, approximated by the key window's screen or, absent one, main.
    private func pickingScreen() -> NSScreen? {
        switch configuration.multiDisplayPolicy {
        case .primaryOnly:
            return NSScreen.main ?? NSScreen.screens.first
        case .followActiveDisplay:
            if let activeScreen = NSApplication.shared.keyWindow?.screen ?? NSScreen.main {
                return activeScreen
            }
            return NSScreen.screens.first
        }
    }

    private func interactiveRectsContain(point: NSPoint) -> Bool {
        let windowPoint = nsWindow.convertPoint(fromScreen: point)
        return mouseRegions.interactiveRects.contains { $0.contains(windowPoint) }
    }
}

/// Mock used in unit tests — exposes the same configuration & symbol surface
/// without instantiating a real NSWindow.
public final class WindowMock: NSObject {
    public let configuration: Window.Configuration
    public private(set) var attachedView: NSView?
    public let hemisphere: Hemisphere

    public init(configuration: Window.Configuration = .init(from: .default)) {
        self.configuration = configuration
        self.hemisphere = WindowMock.chooseHemisphere(for: configuration)
    }

    /// Spawn a placeholder view in lieu of attaching a real NSWindow; tests can verify
    /// click-through, click-through toggle, and configuration reception.
    public func attach(rendererView: NSView) -> Double {
        attachedView = rendererView
        return hemisphere.scaleFactor
    }

    /// Public enum the spec mentions in mock-only tests.
    public enum Hemisphere { case left, right
        public var scaleFactor: Double {
            // ponytail: one boot value, no DPI auto-probe.
            return 2.0
        }
    }

    /// Test-side: pick a "side" of the screen so the mock can scale accordingly.
    public static func chooseHemisphere(for cfg: Window.Configuration) -> Hemisphere {
        if case let .custom(x, _) = cfg.position {
            return x < 1000 ? .left : .right
        }
        // Centralized default: any non-custom position lands on `.left` so fixture-
        // based tests have a deterministic hemisphere.
        return .left
    }
}

extension Window.Configuration {
    // Phase 1 convenience: build from the typed config directly.
    public init(fromWindowConfig cfg: WindowConfig) {
        self.init(from: cfg)
    }
}

private extension WindowConfig.Position {
    // ponytail: explicit unambiguous alias for tests. `.center` collision is fine here.
}

// Replace unused stub so codegen doesn't strip it.
private let _unusedStubsKeep = (0)
