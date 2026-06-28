Status: Approved
Phase: 1 — Foundation
Owner: TBD
-->

# SPEC-006 — Continuous Profiler (Phase 1 bootstrap)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Depends on `spec-003-runtime.md` for the frame gate this Profiler meters.
> Per **D-008** + **D-009**, this Profiler is bootstrapped in Phase 1, not deferred to Phase 8.

---

## 1. Goal

Provide a lightweight, always-on Profiler that the Runtime invokes every frame to sample (a) frame pacing, (b) GPU time per pass, (c) memory (process-wide resident), at a per-frame cost of ≤0.5 ms when enabled and **0** when disabled. The Profiler is the foundation of every later Phase's `Acceptance → Performance metrics` listing.

After SPEC-006 is done, every later Phase Acceptance can use `Profiler.FrameStats` and `Profiler.MemorySample` as canonical inputs without re-implementing measurement.

---

## 2. Deliverables

- `DPProfiler.Profiler`:
  - Singleton-like access: `Profiler.shared` keyed off the Application.
  - Sample types:
    - `FrameStats { dt, gpuMs, cpuMs, droppedFrames }`
    - `MemorySample { residentMB, footprintMB }`
    - `Counter(name: String, value: Double)` — for ad-hoc capture (Phase 2 may use this for draw-call counts).
- `DPProfiler.SamplingPolicy`:
  - `.off`, `.everyFrame`, `.everyNFrames(n)`, `.manual`.
  - Hard cap: when `.everyFrame` is selected, CPU overhead must stay ≤0.5 ms / frame; failing this is an Acceptance failure.
- Subsystem integrations:
  - **Frame Pacing** measures `CADisplayLink` callback-to-callback interval vs target FPS.
  - **GPU Time** measures via `MTLCommandBuffer.gpuStartTime` / `gpuEndTime` properties on the per-frame `MTLCommandBuffer`.
  - **Memory** uses `task_info(mach_task_self(), TASK_VM_INFO, ...)` for resident and footprint.
- **Aggregator**:
  - Rolling window of last 600 frames (~10 s at 60 FPS).
  - Emits `ProfilerEvent.framesPerSecond(window:)` every 1 s.
  - Histogram for `dt` percentiles P50, P95, P99.
- **Tests**:
  - Synthetic load: run a path that hits 1 ms of floating-point work for 600 frames; P99 < 30 ms.
  - Disabled mode: assert zero allocations over 1 s.
  - On/off overhead measurement test: full sample ON cost ≤ 0.5 ms / frame.
- **API docs**: `api/runtime-api.md` (Profiler section).

---

## 3. Out of Scope

- ❌ GPU compute passes / Metal Performance Shader metrics — Phase 2.
- ❌ Profiler UI panel — Phase 8 (spec-037).
- ❌ Telemetry upload — Phase 9.
- ❌ Cross-process profiler (SpriteKit-style external tools).
- ❌ Flame graph generation.

---

## 4. Risk

| Risk | Mitigation |
|---|---|
| `task_info` overhead when sampled every frame | Default policy is `.everyNFrames(60)`; `.everyFrame` requires an explicit `enableForBenchmark()` and is OFF in default CI. |
| Aggregator rolling buffer swallows short spikes | Histogram bins at `dt` bucketed by 0.5 ms granularity; P99 visibility preserved. |
| Sampling race between Metal completion and CPU tick | Profiler samples AFTER Metal `gpuEndTime` is available, never speculatively. |
| Memory sample blocks the Update thread on Mach calls | Memory sample dispatched to a low-priority queue; result available next frame. |
| Profiler data structure adds per-frame allocation | Pre-size all rolling buffers at startup; sample recording uses a fixed-capacity circular buffer. |

---

## 5. Acceptance

### Performance Metrics
- [ ] Profiler `.everyFrame` CPU overhead **≤ 0.5 ms** (measured by phase-difference between profiler-on and profiler-off runs).
- [ ] Aggregator emit latency **≤ 16 ms** after window closes.
- [ ] No per-frame heap allocation during steady-state sampling.

### Enumerable Use Cases
- [ ] Run a 60-frame synthetic loop; `Profiler.shared.windows.lastFramesPerSecond == 60`.
- [ ] Inject 3 simulated dropouts (sleep 50 ms in test driver); `droppedFrames == 3` reported.
- [ ] Memory sample before / after loading `fox.glb`: delta reported within ±0.5 MB.

### Assertable States
- [ ] `Profiler.shared.samplingPolicy` returns current selected policy.
- [ ] `FrameStats` decodes JSON for tests round-trip with stable keys.
- [ ] Disabled mode allocates zero bytes per frame (verified by AllocationTracker test fixture).
- [ ] Rolling window cap = 600.

### Previous-Phase Regression
- [ ] `spec-003-runtime.md` UpdateLoop runs at 60 FPS with Profiler OFF.
- [ ] `spec-005-animation.md` Idle animation continues at 60 FPS with Profiler ON (.everyFrame) in benchmark mode.

---

## 6. Trace

- Implements `roadmap.md` D-008, D-009.
- Provides canonical measurement used by every later Phase's Acceptance.
- Architecture doc: `architecture/lifecycle.md` (Profiler slot in boot order).
- ADR pinned: D-008, D-009.
