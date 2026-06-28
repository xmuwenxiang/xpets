Status: Approved
Phase: 1 — Foundation
Owner: TBD
-->

# SPEC-003 — Runtime Architecture

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Depends on `spec-001-bootstrap.md` (modules) and `spec-002-window.md` (window).
> This is the **lifeblood Spec**: every later Phase depends on the contracts created here.

---

## 1. Goal

Provide the Runtime that owns the Application, Scene root, Update Loop, Render submission, Event Loop, Module Manager, and Shutdown. After SPEC-003 is done, the Runtime is a single `.run()` entry point that owns the entire Application lifecycle and delegates work to registered modules without a tight coupling to any one subsystem.

---

## 2. Deliverables

- `DPRuntime.Application`:
  - Boots in this order: Logger → Config → Window → Modules → Render Surface → Loop.
  - Owns the global `RunLoop` and the **Update / Render frame gate**.
  - Single entry point: `Application.run()`.
- `DPRuntime.Scene`:
  - Holds references to **Asset**, **AnimationState**, **Renderable**, future subsystems.
  - Serialization-ready (so scripts in Phase 7 can address elements by stable IDs).
  - Thou shalt not have a global singleton; the Scene is per-Application.
- `DPRuntime.UpdateLoop`:
  - On each CADisplayLink tick: `modules.update(dt)` → `modules.render(encoder)` → `camera.commit()`.
  - Lock-free or single-mutex dispatch from Render to Main to Module.
  - Catches per-module exceptions; logs and isolates the offending module without halting the loop.
- `DPRuntime.EventLoop`:
  - Wraps `NSApplication` event pump on the main queue.
  - Forwards raw events to subscribed modules (Phase 4 introduces animation events; Phase 5 world events).
- `DPRuntime.ModuleManager`:
  - Modules conform to `RuntimeModule` with phases:
    - `moduleWillBoot(ctx:)`
    - `moduleDidBoot(ctx:)`
    - `moduleWillTick(dt:)`
    - `moduleDidTick(dt:)`
    - `moduleWillShutdown(ctx:)`
  - Managers register modules at boot, single error boundary per module.
- `DPRuntime.ShutdownCoordinator`:
  - Cascades teardown in reverse of boot order.
  - Verifies no Metal resources remain bound via integration test in §5.
- **Frame gate / FPS cap**:
  - Configurable target FPS (60, 30, idle-1).
  - Drives the `Update` cadence via `CADisplayLink`.
  - Wakes up from idle when modules of the Observer protocol require a tick (deferred design — Phase 4 may use this for Random Idle).
- **Tests**:
  - Unit: UpdateLoop pumps deterministic `dt` to a mock module via `LoopTester`.
  - Integration: boot full app, drop in a fake module that throws on `moduleDidTick` — verify loop survives.
  - Lifecycle: boot → run 100 ms → shutdown — verify all module `moduleWillShutdown` hooks fired and Metal resources released.
- **API docs**: `api/runtime-api.md`.

---

## 3. Out of Scope

- ❌ Module-specific logic — those are other Work Specs.
- ❌ Async loader orchestration — SPEC-004 owns asset loading.
- ❌ Multithreaded rendering (Phase 1 is single-threaded Metal submission); GPU work runs in Metal's queue, but the Swift Tick is single-threaded.
- ❌ Hot reload / module swap at runtime — Phase 8 / 9.
- ❌ Telemetry / Crash — Phase 9.
- ❌ Lifecycle save/load — Phase 6.

---

## 4. Risk

| Risk | Mitigation |
|---|---|
| Module crashes the entire UpdateLoop | Per-module error boundary; offending module isolated via a `ModuleState.degraded` flag; future ticks skip it. |
| Race between Metal completion and Swift Update | Use a single dispatch fence at the end of the frame; Render thread completes before next Update starts. |
| Frame jitter from `CADisplayLink` being throttled | Document fallback: explicit `DispatchSourceTimer` if `CADisplayLink` misbehaves (tested with screen unlock scenarios). |
| Shutdown leaks Metal resources | ShutdownCoordinator asserts zero-held `MTLResource` references via a registry counter. |
| Modules register out of order (Renderer after Asset) | ModuleManager uses a topological sort hint with explicit `dependencies: [String]` per module. |

---

## 5. Acceptance

### Performance Metrics
- [ ] `Application.run()` from boot to first frame **≤ 950 ms** (target 1.0 s end-to-end includes this + Window + Asset warm-up).
- [ ] Frame-time P99 over 60 s **≤ 18 ms**.
- [ ] Idle loop CPU **≤ 0.5 %**.
- [ ] Process memory on cold start **≤ 30 MB** (excluding asset memory budget).
- [ ] UpdateLoop overhead per frame **≤ 80 µs**.

### Enumerable Use Cases
- [ ] Boot with zero registered modules → app stays at idle, no crashes, exits on Cmd-Q.
- [ ] Boot with one throwing module → loop survives, log contains the throw, other modules continue.
- [ ] Signaled `SIGINT` → Application initiates `ShutdownCoordinator`.
- [ ] Cmd-Q → graceful shutdown within 200 ms.
- [ ] Boot → run 5 s → shutdown 100×, zero crashes.

### Assertable States
- [ ] `Scene` exposes `assets`, `animationState`, `camera`, `profiler` read-only post-boot.
- [ ] `UpdateLoop` advances `dt` in `[1/240, 1/30]` range; never `0` and never `> 0.5`.
- [ ] `ShutdownCoordinator` declares a deterministic ordering; assert ordering via spec test.
- [ ] `ModuleManager` rejects a module whose declared dependency is missing — fails fast at boot, not at first tick.
- [ ] After full shutdown: `MTLResource.leakedCount() == 0`.

### Previous-Phase Regression
- [ ] `spec-002-window.md` window attach/detach tests still pass after this Spec lands.

---

## 6. Trace

- Implements `roadmap.md` D1, D10.
- Defines `Scene` consumed by `spec-004-asset.md` and `spec-005-animation.md`.
- Architecture doc `architecture/lifecycle.md`, `architecture/threading-model.md` initial content lives here.
- ADR pinned: D-008 (Profiler integration in §6), D-009 (rename — Phase 8).
- API doc: `api/runtime-api.md`.
