# DPWindow API

> Module: `DPWindow` · Owner Phase: 1
> Related: `architecture/desktop-overlay.md`, `specs/Phase-1-Foundation/spec-002-window.md`

---

## Public Surface

```
public final class Window {
    public init(config: WindowConfiguration)
    public func attach(view: MTKView) throws
    public func detach() async
    public func applyDisplayChange(_ screen: NSScreen) throws
}

public final class MouseRegions {
    public init(window: Window)
    public func addInteractive(rect: CGRect, id: UUID)
    public func removeInteractive(id: UUID)
    // Phase 5 use only — interface-only in Phase 1.
}

public struct WindowConfiguration {
    public var positionPolicy: PositionPolicy = .centerOnPrimary
    public var multiDisplayPolicy: MultiDisplayPolicy = .followActiveDisplay
    public var initialPosition: InitialPosition?
    public var clickThroughByDefault: Bool = true
}
```

## Invariants

- After `attach`, `Window.styleMask == [.borderless]`, `window.isOpaque == false`.
- `Window.ignoresMouseEvents == true` by default (Phase 1).
- A phase-5 future may flip `ignoresMouseEvents` per-region via `MouseRegions` (interface-only in Phase 1).

## Error Modes

| Method | Throws |
|---|---|
| `attach` | `NativeLayerError` (Sonoma) |
| `applyDisplayChange` | `MultiDisplayError` |

## Test Hooks

- `WindowStub` (in tests): mocks AppKit without an actual window.
- `NSScreenMock` (in tests): injects custom `backingScaleFactor`.

## Status

**Stub**. Filled when `spec-002-window.md` lands.
