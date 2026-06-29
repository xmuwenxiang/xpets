<!--
Status: Implementing
Phase: 2 — Rendering
Owner: Xavier Zhang
Depends: Phase 1 spec-001-bootstrap.md, spec-002-window.md, spec-003-runtime.md, spec-004-asset.md, spec-006-profiler.md
ADRs:   D-005 (Phase 5 split), D-008 (Continuous Profiling budget line), D-013 (4-category Acceptance)
-->

# SPEC-001 — Metal Renderer (Phase 2 backbone)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Replaces the Phase-1 clear-color stub (`DPRenderer.Renderer.drawClear(_:)`) with the production renderer entry path. Pass registration + Command-Queue lifetime stay single-threaded on the Renderer thread owned by Phase-1 `Runtime`.
> This is **not** the render-route decision (which Phase 5a decides per `Phase-2/overview.md` Cross-References). This spec only governs the *renderer* surface, not the **route** the fox takes to the desktop.

---

## 1. Goal

Provide a Metal-backed renderer with Pass registration, GPU-time sampling, and stable command-queue lifecycle, sitting on top of Phase-1 `DPRenderer.Renderer.drawClear(_:)`. After SPEC-001 ships, every later Phase Work Spec in Phase 2 may register a Pass without touching the command queue, and every pass's GPU time is measurable per frame via the Profiler `Counter` interface.

---

## 2. Deliverables

- `DPRenderer.Renderer` extends with:
  - `registerPass(_ pass: RenderPass, after: RenderPass.ID? = nil)` — insertion-order with optional anchor; first pass becomes `RenderPass.ID.root`.
  - `unregisterPass(id: RenderPass.ID)` — released on the next `present` tick.
  - `currentFrameIndex: UInt64` — monotonically increasing per `tick(dt:)`; `RenderPass` implementations read it to gate frame-locked resources.
- `RenderPass` protocol:
  - `associatedtype Context`
  - `func encode(into commandBuffer: MTLCommandBuffer, context: Context) -> RenderPass.ID`
  - `var gpuLabel: String { get }` — used by the Profiler `Counter(name: gpuLabel, value:)`.
- `MTLDevice` lifetime owned by `Renderer` (Phase-1 already created; this spec only ensures no second `MTLCreateSystemDefaultDevice` call exists elsewhere — asserted in tests).
- Pass execution order is stable across frames; order mutations surface a debug-warning log but never reorder mid-frame (assert in test).
- **Tests** (TDD per D-002):
  - Unit: register A → B → C; assert execution order `[A, B, C]`.
  - Unit: unregister middle; assert remaining `[A, C]` and no use-after-free.
  - Integration: a no-op Pass records a `Counter`; after 60 frames assert average ≤ X ms (X bound below).
- **API docs**: `api/renderer-api.md` — order semantics, threading contract (single Renderer thread), MTLCommandBuffer retain-cycle prohibition.
- **Profiler integration**: every Pass emits `Counter(name: gpuLabel, value: gpuMs)` via `Profiler.shared.recordCounter`.

---

## 3. Out of Scope

- ❌ **PBR material pipeline** — `spec-002-material-pbr.md`.
- ❌ **Lighting / IBL** — `spec-003-lighting.md`.
- ❌ **Shadow** — `spec-004-shadow.md`.
- ❌ **HDR / Tone Mapping / FXAA / Bloom** — `spec-005-hdr-post.md`.
- ❌ **Render-route decision** (offscreen-compositor vs direct-on-window) — Phase 5a; deliverable lands at `Phase-5/...` not here.
- ❌ **Cross-platform** — explicitly out of Phase 2 (Apple Silicon only, matches Phase 1 gate).
- ❌ **Multi-Pet cohabitation** — post-Phase 9.

---

## 4. Risk

- **Render pass order drift under late registration** — Mitigation: late `registerPass` after `bootAll` throws `RendererError.alreadyRunning`; registration only legal during module-boot window.
- **MTLCommandBuffer retain cycle** (encoder → buffer → encoder) — Mitigation: assertion in tests fails CI if encoded buffer outlives the `present()` tick by more than one frame.
- **GPU-time measurement cost** — Mitigation: `gpuStartTime / gpuEndTime` read is already O(1); if Profiler overhead exceeds 0.5 ms / frame, Profiler falls back to `.everyNFrames(60)` automatically.
- **Thread boundary violation** (Phase-1 Runtime ticks on main thread; Pass encoding on Renderer thread) — Mitigation: `RenderPass.Context` is `Sendable`-annotated; the protocol itself encode-only forbids re-entrant calls.
- **Apple Silicon vs Intel simulator divergence** — Mitigation: CI uses `macos-14` runner (Apple Silicon only); Intel path is explicitly unsuppported in Phase 2.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `Renderer.tick(_:)` wall-clock cost **≤ 4 ms** at 60 FPS with 6 Passes registered (CPU-side budget, excludes GPU pass cost).
- Per-Pass GPU-time percentile P99 over 600-frame window is logged via `Profiler`; for the backbone no-op Pass (dispatch overhead only) CI asserts P99 ≤ 0.5 ms. Heavy passes (Material / Lighting / Shadow / HDR) carry their own per-spec P99 budgets and are exempt from this generic ceiling.
- Profiler `.everyFrame` overhead remains ≤ 0.5 ms / frame (Phase 1 row 24 regression) when a Pass emits a `Counter`.

### Enumerable use case

- Register-then-unregister cycle: starting from `[root]`, add 4 passes → order is deterministic `[root, A, B, C, D]` → unregister `B` → final order `[root, A, C, D]`.
- Re-register same Pass ID twice: second call returns `RendererError.duplicatePassID` and the original ID is preserved.
- Inject a Pass that throws inside `encode(into:context:)` (test-only backdoor): the Renderer logs the throw, drops the Pass after the frame, and continues ticking — **Loop survives** invariant (matches Phase 1 spec-003 §5 row).

### Assertable state

- `Renderer.currentFrameIndex == 0` immediately after `init`; increments by exactly 1 per `tick(dt:)` call.
- `MTLDevice` reference count in process = 1 (asserted via `gpuCount` test fixture).
- After `unregisterPass(id:)` the pass's encoder closure is deallocated — `weak var weakPass` test asserts `weakPass == nil` after drain.
- A register call **after** the first `tick(dt:)` is rejected with `RendererError.alreadyRunning`.

### Previous-Phase regression

- All Phase 1 `acceptance.md` rows 1..31 still pass at `acceptance.md` baseline — re-run `swift test` and CI green.
- Memory baseline ≤ 65 MB worst-case (Phase 1 row memory reconciliation) **must not exceed 80 MB** — Phase 2 Renderer may add ≤ 15 MB ceiling for pass / command-buffer pool.
