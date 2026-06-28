Status: Approved
Phase: 1 — Foundation
Owner: TBD
-->

# SPEC-002 — Window System

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Depends on `spec-001-bootstrap.md`. Provides the host NSWindow for `spec-003-runtime.md`.

---

## 1. Goal

Provide a Swift wrapper around `NSWindow` that hosts a transparent, borderless, always-on-top, click-through overlay suitable for the entire Runtime to render onto. The host surface must survive multi-display reconnects and DPI changes without restart.

When SPEC-002 is done, calling `Window.attach(view:)` gives the caller a Metal-backed view rendered above all standard windows, with click-through enabled by default, without visual chrome (no title bar / shadow / rounded corners / close button).

---

## 2. Deliverables

- `DPWindow.Window` final class wrapping `NSWindow`:
  - **Transparent**: `backgroundColor = .clear`, `isOpaque = false`.
  - **Borderless**: `.borderless` style mask; `hasShadow = false`.
  - **Always-on-top**: `.floating` or above-window level + `NSWindow.canJoinAllSpaces = true`.
  - **Click-through default**: `ignoresMouseEvents = true`. Programmatic per-region toggle reserved for Phase 5.
  - **Multi-display awareness**: subscribes to `NSApplication.didChangeScreenParametersNotification`.
  - **DPI awareness**: scales the underlying `MTKView` by `NSScreen.backingScaleFactor`.
  - **Sonoma-safe selector masks**: enforces `gestureRejectable = true` and bottom-edge exclusion rect.
- `DPWindow.MouseRegions` (future-facing interface only — not used in Phase 1):
  - Methods: `addInteractive(rect:)`, `removeInteractive(rect:)`.
  - Implementation deferred; the protocol surface exists for Phase 5 to use.
- `Window Configuration` typed struct (from `DPFoundation.Config`):
  - `position: .center | .topLeft | (x, y, w, h)`
  - `multiDisplayPolicy: .primaryOnly | .followActiveDisplay`
- **Tests**:
  - Unit: verify `Window.attach` produces a window with the four required properties.
  - Integration: launch the app, attach the window, take a synthetic event hit-test on the window's rect; assert the hit is NOT consumed.
- **API docs**: `api/window-api.md` produced — full Swift signatures, invariants, threading contracts.

---

## 3. Out of Scope

- ❌ Drawing any 3D content — handled by `spec-005-animation.md` and Phase 2.
- ❌ Per-region interactivity — Phase 5 (D-005). The protocol surface is reserved only.
- ❌ Hot-reload of window config without app restart.
- ❌ Multiple windows / draggable windows for multi-pet — Phase 9 ("multiple pets" feature).
- ❌ Saving window position across launches (e.g. across-reboot persistence) — Phase 6.

---

## 4. Risk

| Risk | Mitigation |
|---|---|
| NSWindow click-through misbehaves when the app is `.hidden` then `.shown` | Reset `ignoresMouseEvents = true` on every `applicationDidBecomeActive`. |
| Sonoma behavior change breaks `.floating` ordering above full-screen video | Use `.init(rawValue: NSWindow.Level(rawValue: CGWindowLevelForKey(.maximumWindow)) + 1)` with a lockfile comment to retest each macOS upgrade. |
| Multi-display reconnect drops the window mid-frame | Subscribe to `didChangeScreenParametersNotification`; on lost display, move to `.main` and emit a `Window.displayLost` event. |
| Concurrent screen-DPI differing between displays on hybrid GPU laptops | Re-create `MTKView` when `backingScaleFactor` changes; render-thread-safe via a dispatch-fence. |
| Apple Silicon-only mismatch on Intel Macs | Add a startup assertion: `ProcessInfo.processInfo.machineHardwareType` must be `arm64`; otherwise show a clear UI screen. |
| Window becomes visible during boot before transparent style applied | Initialize style mask + `isOpaque = false` BEFORE `makeKeyAndOrderFront`. |

---

## 5. Acceptance

### Performance Metrics
- [ ] `Window.attach` time **≤ 50 ms**.
- [ ] Display reconfiguration handler **≤ 16 ms**.
- [ ] Window must not contribute more than **0.5 ms frame overhead** when rendering idle.
- [ ] Memory contribution of Window subsystem **≤ 1 MB**.

### Enumerable Use Cases
- [ ] Single-display: window centers to primary display.
- [ ] External display present: window centers to combined display if `multiDisplayPolicy = .followActiveDisplay`.
- [ ] Click on the fox's bounding box: click event reaches app underneath DesktopPet (verified via hit-test unit test).
- [ ] Cmd-Tab away from DesktopPet and back: window remains visible at the correct z-order.
- [ ] Quit: window closes cleanly, Metal resources released (verified by lifecycle test in SPEC-003).

### Assertable States
- [ ] `Window.styleMask` returns exactly `[.borderless]` after construction.
- [ ] `Window.isOpaque` returns `false`.
- [ ] `Window.backgroundColor` returns `.clear` (alpha 0).
- [ ] `Window.level == CGWindowLevelForKey(.maximumWindow) + 1` numerically.
- [ ] `Window.ignoresMouseEvents == true` after `attach`.
- [ ] Window appears at position `(x, y)` from config when configured with explicit coords.
- [ ] A test injects a `NSScreen` mock returning `backingScaleFactor = 2.0`; window scales correctly.

### Previous-Phase Regression
- [ ] Cold `swift build` still succeeds after this Spec lands (regression on SPEC-001 module binding).

---

## 6. Trace

- Implements `roadmap.md` D-001, D-010.
- Reserves hover/click contract used by Phase 5a `spec-NNN-desktop-discovery.md` (file NNN chosen at Phase 5a start).
- Architecture doc `architecture/desktop-overlay.md` is updated here.
- ADR pinned: D-010 (Apple Spec style); D-005 referenced only as forward pointer (Phase 1 work does not depend on Phase 5 split).
