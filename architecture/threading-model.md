# Threading Model

> Threads, queues, fences, IPC for the AI Native 3D Desktop Pet.

---

## Threads

| Thread | Owner | Purpose |
|---|---|---|
| **Main** | `NSApplication` | Event loop (mouse, keyboard, window), AppKit-bound calls |
| **Render-Command Queue** | Metal driver's queue | Per-frame Metal command buffer submission |
| **Asset Worker** (Phase 1: off Main via GCD) | `DPAsset.Loader` | Asynchronous GLB / KTX2 decoding |
| **Claude IPC** (Phase 7) | UnixSocket / JSON-RPC worker | Async Claude CLI ↔ Runtime intent exchange |
| **Telemetry** (Phase 9) | Background queue | Opt-in event upload |

---

## Queues / Dispatch Boundaries

- **Update dispatch**: from `CADisplayLink` callback on Main, the Application calls `moduleWillTick(dt:)` then `moduleDidTick(dt:)`. Modules **must not block** the Update thread.
- **Render dispatch**: `MTKView.draw()` callback runs on the Render-Command Queue; Application waits for `MTLCommandBuffer.gpuEndTime` before next frame for Profiler's GPU-time measurement (D-008).
- **Asset load**: dispatch to Asset Worker via GCD; result returned via async/await. Single-flight decode enforced (per `spec-004-asset.md` Acceptance item 14).

---

## Locks / Fences

- **`Scene` State Lock**: a `Mutex<Scene>` wraps the Scene graph. Modules acquire during their `tick` only; render side reads through a copy-on-tick snapshot. Defer to Phase 2 if profiling shows contention.
- **Module Registry Lock**: held briefly during registration; modules then own a `weak` reference.
- **Metal Fence**: `MTLCommandBuffer` completion is awaited via dispatch-fence during shutdown.

---

## Failure Modes

- Module crashes do not halt UpdateLoop (per `spec-003-runtime.md` Acceptance 19).
- Asset Worker disables itself under memory pressure; the boot path falls back to synchronous on Main (rare, only when Memory Pressure is "Critical").
- Claude IPC worker keeps a `lastSeenTimestamp`; ≥ 30 s of silence triggers Failure Mode Matrix protocol (Phase 7).

---

## Status

**Stub**. Precise queue contracts fill as Phase 1 modules land. Phase 7 (Claude IPC) and Phase 9 (Telemetry) extend.
