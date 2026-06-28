<!--
Status: Draft
Phase: 5b — DesktopWorld
Owner: TBD
Depends: spec-001-desktop-discovery.md
-->

# SPEC-003 — World Events (WindowChange / AppSwitch / ScreenChange / DisplayConfigChange)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Event sources drive the entity catalog. The contract is producer-side: any getter of these events triggers a single debounced push to subscribers.

---

## 1. Goal

Provide a unified event stream for desktop changes — WindowChange (window added/updated/removed), AppSwitch (active app changes), ScreenChange (display topology), DisplayConfigChange. After SPEC-003 ships, the entity catalog (`spec-001`) subscribes to this stream and pushes delta events to Phase 5b NavMesh / Phase 6 Behavior without re-querying AppKit directly.

---

## 2. Deliverables

- `DPDesktop.WorldEventBus`:
  - Singleton-ish access: `WorldEventBus.shared`.
  - Emits typed events: `WindowChange`, `AppSwitch`, `ScreenChange`, `DisplayConfigChange`.
  - Subscription: `bus.subscribe(handler:)` returns a cancellable token.
- Source-mappings:
  - `WindowChange` ← `NSWindow.didChangeScreenParametersNotification` + `NSWindow.didBecomeKeyNotification` (throttled).
  - `AppSwitch` ← `NSWorkspace.didActivateApplicationNotification`.
  - `ScreenChange` ← `NSApplication.didChangeScreenParametersNotification`.
  - `DisplayConfigChange` ← `CGDisplayRegisterReconfigurationCallback`.
- **Debounce strategies** per event type:
  - `WindowChange`: 100 ms debounce; bundled batch of changes emitted as one event.
  - `AppSwitch`: no debounce — single event.
  - `ScreenChange`: 250 ms debounce.
  - `DisplayConfigChange`: no debounce.
- **Tests** (TDD per D-002):
  - Unit: simulate 30 WindowChange events within 50 ms → exactly 1 emitted-after-debounce event with all 30 changes bundled.
  - Unit: AppSwitch streams one event per activation.
  - Unit: ScreenChange debounce: 4 screen-parameter changes within 100 ms → 1 emitted event.
  - Unit: subscription cancel: token-deallocated handlers do NOT receive subsequent events.
- **API docs**: `api/world-events-api.md` — debounce policy, cancel tokens, threading.

---

## 3. Out of Scope

- ❌ Beacon events for Phase 6 Behavior — Phase 6 supplies behavior-driven events.
- ❌ High-frequency mouse cursor events — Phase 5 only handles these if needed for `LookAtIK` (`spec-004-desktop-world.md` cross-ref).
- ❌ Network / IPC events — out.

---

## 4. Risk

- **Multi-display state drift** — Mitigation: handle debounce carefully; re-binding display config must NOT cause entity catalog to dump 100+ events in one frame.
- **Window-change flood during drag-resize** — Mitigation: 100 ms debounce on WindowChange absorbs flood; final state is consistent.
- **NotificationCenter double-registration** — Mitigation: WorldEventBus owns the internal `NotificationCenter`; no caller may subscribe directly.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Debounce flush latency P99 ≤ 110 ms for WindowChange (debounce + frame budget).
- Per-frame emission cost ≤ 50 µs.
- Memory delta ≤ 1 MB on top of Phase-4 baseline.

### Enumerable use case

- 30 synthetic WindowChange events within 50 ms → exactly 1 bundled debounced event.
- 4 screen-parameter changes within 100 ms → 1 ScreenChange event.
- Subscription cancel: token-deallocated handler does NOT receive further events.

### Assertable state

- `WorldEventBus` thread-safe; `Sendable`-safe across threads.
- Debounce policy is per-event-type (assertable in test policy table).
- Token cancellation is one-way: cancelled tokens cannot be re-subscribed.

### Previous-Phase regression

- Phase 1..4 `acceptance.md` items still pass.
- Phase-3 `collisionLayer: .edge` unchanged.
- Profiler `.everyFrame` budget unchanged.
