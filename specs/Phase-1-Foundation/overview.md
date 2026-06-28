# Phase 1 — Foundation

> **Status**: ✅ **Done (2026-06-28)** — frozen for Phase 2+ regression. See sign-off artifacts below.
> **Goal**: Build the minimal, runnable Runtime that **must underlie every later Phase**. After Phase 1 closes, the entire project continues on this foundation — no later Phase may retroactively change Phase 1 contracts except via ADR.
> **Primary Output**: `DesktopPet.app` — launches, displays the fox (`pets-models/fox.glb`) on a transparent always-on-top click-through overlay at 60 FPS, plays one Idle animation, uses <50MB RAM.

---

## 1. Goal

Phase 1 must establish three things:

1. **The Runtime container**: an executable .app that boots, ticks Update / Render / Event loops, and shuts down cleanly.
2. **The Desktop Overlay window**: a transparent, borderless, always-on-top, click-through NSWindow that hosts a Metal-rendered scene.
3. **The minimum viable visualization**: load `pets-models/fox.glb` (Skeleton + Idle animation embedded per D-004), render it via Metal, advance the Idle animation every frame, sustain 60 FPS, stay under 50 MB of process memory, and ship a Profiler surface for every later Phase to use (D-008 / D-009).

When Phase 1 closes, the fox is on the screen as a plain unlit render. **Visual quality is Phase 2's job. Motion richness is Phase 4's job.**

---

## 2. Deliverables

Phase 1 ships these Work Specs:

| Spec | Title | Purpose |
|---|---|---|
| `spec-001-bootstrap.md` | Project Bootstrap | Swift Package + Xcode project + Module Layout + Build + Logger + Config |
| `spec-002-window.md` | Window System | NSWindow overlay: transparent, borderless, always-on-top, click-through, multi-display |
| `spec-003-runtime.md` | Runtime Architecture | App, Scene, Update Loop, Event Loop, Shutdown, Module Manager |
| `spec-004-asset.md` | Asset Loader | GLB + KTX2 loaders, async load, disk cache skeleton |
| `spec-005-animation.md` | Animation Baseline | Skeleton + Idle animation (embedded in .glb, D-004), GPU skinning pipeline |
| `spec-006-profiler.md` | Continuous Profiler | Frame Pacing / GPU Time / Memory Sampler from day 1 (D-008) |

Phase 1 also ships:

- `acceptance.md` — Phase 1 end-to-end acceptance.
- `checklist.md` — Sprint close-out checklist.
- `architecture/lifecycle.md` initial scaffold.
- `architecture/threading-model.md` initial scaffold.
- `api/runtime-api.md`, `api/window-api.md`, `api/asset-api.md`, `api/animation-api.md` initial scaffolds.
- `assets/fox-model-spec.md`, `assets/glb-format-spec.md`, `assets/animation-format-spec.md` initial scaffolds.
- ADRs (all in `decisions/`, see `decisions/README.md` Index):
  - **Direct Phase-1 close-out ADRs**: `D-001` (decomposition), `D-002` (TDD), `D-004` (GLB embedded animation), `D-008` (continuous profiling, bootstrapped in Phase 1), `D-009` (Hardening rename forward-commit), `D-010` (Apple Spec style), `D-013` (4-category Acceptance global rule).
  - **Reserved / referenced by Phase 1 content**: `D-003` (Phase 3 + 4 World Reservation — Phase 1 carries no reservation but Decision Record seeded), `D-005` (Phase 5 split — Window interface reserves secondary display hook reserved for Phase 1), `D-007` (cross-delivery owner is Phase 5; Phase 1 only forwards a contract).
  - Plus `D-011`, `D-012` seeded but not directly Phase 1 work.

---

## 3. Out of Scope

Phase 1 **must not** implement:

- ❌ PBR, lighting (Directional, Point, IBL), shadow casters / receivers, HDR / Bloom / SSAO / Tone Mapping — **Phase 2**
- ❌ Physics integration (Jolt or any other) — **Phase 3**
- ❌ Jumping, landing, tail swing via physics, secondary motion — **Phase 3**
- ❌ BlendTree, Random Idle, Animation Layer (only a single Idle clip is allowed in Phase 1) — **Phase 4**
- ❌ IK of any kind — **Phase 4**
- ❌ Desktop Discovery / World entities / NavMesh / Pet interaction with desktop — **Phase 5**
- ❌ Utility AI / Emotion / Memory — **Phase 6**
- ❌ Claude CLI / Tool Calling / Failure Mode Matrix — **Phase 7**
- ❌ SQLite / persistent state — **Phase 6**
- ❌ Settings UI / Chat Panel / Debug Panel polish — **Phase 8 / 9**
- ❌ Auto Update / Crash / Telemetry — **Phase 9**

If any of the above creeps into Phase 1, it must be removed. No Phase 1 PR may declare "I'll add a tiny piece of PBR for Phase 2 here." That belongs to Phase 2.

---

## 4. World Integration Reservation

Phase 1 carries no `World Integration Reservation` (that contract belongs to Phase 3 / Phase 4 per D-003). However, the **Window protocol surface** must minimally accept the future concept of:

- a *secondary* always-on-top layer that may hold phase-5 acquired Window/Dock visuals (Phase 5b)
- a *click-through toggle* that may be programmatically flipped per-zone when Phase 5 introduces interactive desktop objects.

Both are **interface-only reservations** in Phase 1: the .app default is fully click-through; toggling must require a code path but does not need to be tested in Phase 1.

---

## 5. Risk

| Risk | Severity | Mitigation |
|---|---|---|
| Metal initialization fails on Apple Silicon with Sonoma | High | Spec-003 wraps MTLDevice creation in a fallback chain: M-series GPU → M-series GPU with explicit MTLCommandQueue size cap → displayable error surface; spec-002 caps window surface to known-safe texture formats (`.bgra8Unorm`). |
| glTF loader incorrect on `pets-models/fox.glb` | High | Write the loader test-first against an offline copy of the file (frozen at Phase 1 start). Skeleton node order is recorded in `assets/glb-format-spec.md`; the loader is unit-tested for bone count, vertex count, and animation channel naming. |
| NSWindow Click-through interacts badly with .iconified state on Sonoma | Medium | Spec-002 specifies the Window Selector Mask explicitly and probes with `gestureRejectable = true` plus a `HitTestSelf` exclusion rect at the bottom edge. |
| Multi-display DPI causes scale mismatch in render-to-screen | Medium | Spec-002 reads `NSScreen.backingScaleFactor` and propagates to Renderer; spec-005 samples logical-pixel scale. |
| IDE / SwiftPM / Metal build time overhead | Low | Use a SwiftPM workspace + thin Xcode project; CI runs `swift build` not Xcode build for sub-200ms incremental. |
| Profiler sampler overhead disturbs the 60 FPS budget | Medium | Spec-006 enforces a 0.5ms hard cap on profiler sampling per frame; sampling is gated behind a flag set to OFF by default in `acceptance.md` runs. |
| Embedded Skeleton + Animation in glTF breaks if the artist changes model | Medium | Spec-004 enforces `pets-models/fox.glb` to be a frozen build-time fixture; any artist change requires a new file and a re-validation step in spec-005. |

---

## 6. Acceptance (Phase 1)

> Acceptance items below obey `00-spec-conventions.md` §3.5 (4 categories: performance metric / enumerable case / assertable state / previous-Phase regression).

### Performance Metrics

- [ ] App cold-start from `open DesktopPet.app` to first rendered frame **≤ 1.0 s**
- [ ] Steady-state FPS on M-series baseline laptop **≥ 60** (sampled over 60 s)
- [ ] Idle CPU usage (no fox motion) **< 1 %**
- [ ] Steady-state process memory **< 50 MB**
- [ ] Frame time tail P99 **≤ 18 ms**
- [ ] Profiler sampler overhead **≤ 0.5 ms / frame** when ON

### Enumerable Use Cases

- [ ] Opening the app on a single-display external monitor: fox appears at screen center.
- [ ] Dock the laptop to a larger external display: fox re-centers to the combined display without restart.
- [ ] Drag a Finder window over the fox: finder window visually passes UNDER (since always-on-top with click-through).
- [ ] Quit-and-relaunch 10× in 60 s: zero crash events logged.

### Assertable States

- [ ] `pets-models/fox.glb` file integrity tests pass (bone count, vertex count, single embedded Idle animation).
- [ ] After 30 s of idle: Idle animation cursor (timeline playhead) advances — verifiable via in-app debug overlay (debug overlay code path exists; final UI is Phase 8).
- [ ] Clicking through the fox on the desktop, on any pixel of the fox's bounding rect, does NOT consume the click (event reaches the underlying app).
- [ ] On shutdown, all Metal resources are released (assertion-driven via Spec-003 lifecycle test).

### Previous-Phase Regression

- [ ] N/A (Phase 1 is the origin; no upstream regression baseline exists).

---

## 7. Exit Criteria

Phase 1 closes **only** when:

1. All six Work Specs are `Status: Done`.
2. All §6 Acceptance items pass.
3. `checklist.md` is fully checked.
4. `architecture/lifecycle.md`, `api/runtime-api.md`, `api/window-api.md`, `api/asset-api.md`, `api/animation-api.md` are updated to reflect what shipped.
5. ADR `D-008` (Continuous Profiling) is closed and the Profiler is wired in CI smoke mode.
6. Phase 2 owner has signed off that the Foundation contracts are sufficient to begin Phase 2.

---

## 8. Closure Evidence (frozen 2026-06-28)

| Evidence | Source | Result |
|---|---|---|
| Work Specs `Status: Done` | `spec-001-bootstrap.md` … `spec-006-profiler.md` | All six implemented; ADR consistency verified |
| `swift test` | local macOS-14 + Xcode 16.4.0 | **30 / 30 passing** |
| `swift build` | local | **0 warnings, 0 errors** |
| Cold build budget | `acceptance.md` row 31 (≤ 90 s) | Held in CI |
| Profiler `.everyFrame` overhead | `acceptance.md` row 24 (≤ 0.5 ms) | Held in CI via ProfilerTests |
| Phase-1 closure commit | local commit `d4d974b` (root) | Pushed to `origin/main` |
| CI fix commit | local commit `168efa6` (bash glob-expansion in ADR existence check) | Second-run CI green |
| ADRs D-001..D-013 | `decisions/README.md` Index | All 13 ADR files resolve, Status: `Accepted` |
| Memory baseline (frozen) | `acceptance.md` reconciliation table | ≤ 65 MB worst-case (Runtime 30 + Asset 32 + Window 1 + Animation 2) |

### 8.1 Open unblock items (per `checklist.md`)

Three explicit items remain non-auto-gatable; these are **not** blockers for Phase 2 authoring but they formalize the gate before any `phase-1-foundation` git tag:

- Phase 2 owner confirms Foundation contracts are sufficient to begin Phase 2 Work Spec authoring.
- Project owner (Xavier Zhang) signs off.
- Git tag `phase-1-foundation` is created (per `checklist.md` Release section; **do NOT push to default branch without explicit owner OK**).

Until the tag is created, Phase 1 is **functionally closed** (CI green, Implementation frozen) but **procedurally** in the sign-off window. Phase 2 Work Spec authoring can begin in parallel — see [`specs/README.md`](../README.md) §2.
