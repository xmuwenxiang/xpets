# Desktop Overlay

> The NSWindow surface that hosts the AI Native 3D Desktop Pet. The window is **transparent**, **borderless**, **always-on-top**, **click-through default**.

---

## Properties (Phase 1)

| Property | Value | Source |
|---|---|---|
| `styleMask` | `[.borderless]` | `spec-002-window.md` Deliverable 2 |
| `isOpaque` | `false` | D-013 Acceptance 3.a |
| `backgroundColor` | `.clear` (alpha 0) | Same |
| `level` | `CGWindowLevelForKey(.maximumWindow) + 1` | Risk mitigation (Sonoma full-screen above-window) |
| `canJoinAllSpaces` | `true` | Always-on-top semantics |
| `ignoresMouseEvents` | `true` (default) | Click-through default |
| `hasShadow` | `false` | Borderless |

---

## Multi-Display Hook

- Subscribes to `NSApplication.didChangeScreenParametersNotification`.
- On reconnect, window recenters per `multiDisplayPolicy` config (`.primaryOnly` or `.followActiveDisplay`).
- DPI: re-reads `NSScreen.backingScaleFactor` per display; `MTKView.setContentScaleFactor(...)` called accordingly.

---

## Reserved Hooks (Phase 5 forward-compatibility, D-005)

- A** secondary layer concept** for Phase 5-acquired Dock/Window visuals.
- A** per-zone click-through toggle** when Phase 5 introduces interactive desktop objects.

These are **interface-only** in Phase 1; no implementation.

---

## Status

**Active in Phase 1 spec.** Implementation fills when `spec-002-window.md` lands.
