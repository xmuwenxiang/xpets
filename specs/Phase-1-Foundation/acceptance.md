# Phase 1 — Acceptance (End-to-End)

> This file lists every Acceptance criterion for Phase 1 in **one place**, mapping each to the Work Spec that owns it. Used during the Phase close-out review and for E2E demo scripting.

> Convention reminder: every criterion falls in one of 4 categories (Performance / Enumerable / Assertable / Regression). See `specs/00-spec-conventions.md` §3.5.

> **P99 frame-budget disambiguation** — frame-time P99 numbers in this file have two distinct ownerships:
> - **Acceptance items 6, 10** (`≤ 18 ms` / `≤ 16 ms`) measure the **Runtime as a system** while running the fox + Window + Asset + Animation + idle Profiler. They are the user-visible quality gate.
> - **`spec-006-profiler.md` §5**'s "synthetic load" P99 (`≤ 30 ms`) measures the **Profiler-as-instrument** under a 1 ms of floating-point work injection per frame. This is a Profiler self-test, not a Runtime-quality measure. The two numbers coexist; neither supersedes the other.

---

## A.1 Cold Start to Visible Fox

| # | Item | Category | Owner Spec | Verifier |
|---|---|---|---|---|
| 1 | Cold-start to first rendered frame ≤ 1.0 s | Performance | spec-003 + spec-002 | Benchmark test |
| 2 | Apple Silicon-only assertion gate | Assertable | spec-002 | Unit test |
| 3 | Window attaches transparent / borderless / always-on-top / click-through | Assertable | spec-002 | Unit test |
| 4 | Multi-display reconnect does not lose the fox | Enumerable | spec-002 | Manual demo |
| 5 | Cmd-Q → app shuts down within 200 ms, no Metal leak | Enumerable | spec-003 | Integration test |

## A.2 Steady-State Frame

| # | Item | Category | Owner Spec |
|---|---|---|---|
| 6 | Frame time P99 ≤ 18 ms over 60 s | Performance | spec-003 |
| 7 | Idle CPU ≤ 1 % | Performance | spec-003 |
| 8 | Steady-state memory ≤ 50 MB | Performance | spec-003 + spec-004 + spec-005 + spec-006 |
| 9 | Idle animation advances every frame | Assertable | spec-005 |
| 10 | Idle animation drift over 60 s ≤ 16 ms | Performance | spec-005 |

**Memory reconciliation (item 8)** — the three memory numbers in Phase 1 specs are intentionally sub-budgets that add into a single owner cap:

| Spec | Subsystem | Cap |
|---|---|---|
| `spec-003` | Runtime cold-start (before any asset load) | ≤ 30 MB |
| `spec-004` | Asset memory cache footprint upper-bound | ≤ 32 MB |
| `spec-002` | Window subsystem | ≤ 1 MB |
| `spec-005` | Animation (skinning buffers + skeleton pose) | ≤ 2 MB |
| **Sum (worst-case)** | | **≤ 65 MB** |

The Phase 1 steady-state cap of **≤ 50 MB** (acceptance item 8) is achievable because:

1. Asset cache cap (32 MB) is **upper-bound**, not baseline — the GLB binary only spends ~30 MB transiently while loading; warm steady-state uses 8–15 MB of cache.
2. Animation buffers are preallocated once (≤ 2 MB) and reused — no per-frame allocation.
3. The cold-start budget (30 MB) is a one-shot at boot; once `pets-models/fox.glb` loads, the runtime-frame budget shadows it.

The reconciliation is enforced by a **memory-budget test** in `_test/MemoryBudgetTests.swift` which samples RSS at t = 30 s and t = 5 min after launch.

## A.3 Asset & Animation

| # | Item | Category | Owner Spec |
|---|---|---|---|
| 11 | `pets-models/fox.glb` integrity (bone count, mesh, single Idle) | Assertable | spec-004 + spec-005 |
| 12 | Cold load ≤ 150 ms | Performance | spec-004 |
| 13 | Memory cache hit ≤ 5 ms | Performance | spec-004 |
| 14 | Single-flight concurrency held | Assertable | spec-004 |
| 15 | Renderer pixels change between frame 1 and frame 60 | Assertable | spec-005 |

## A.4 Click-through Behavior

| # | Item | Category | Owner Spec |
|---|---|---|---|
| 16 | Click on fox's bounding box reaches underlying app | Enumerable | spec-002 |
| 17 | Click-through toggleable via reserved protocol (not used) | Assertable | spec-002 |

## A.5 Resilience

| # | Item | Category | Owner Spec |
|---|---|---|---|
| 18 | 10× cold relaunch in 60 s, zero crash | Enumerable | spec-001 + spec-003 |
| 19 | Throwing module does not halt UpdateLoop | Enumerable | spec-003 |
| 20 | SIGINT triggers graceful shutdown | Enumerable | spec-003 |
| 21 | ShutdownCoordinator produces deterministic order | Assertable | spec-003 |
| 22 | Zero Metal resource leak on shutdown | Assertable | spec-003 |
| 23 | Malformed GLB returns `.decodeError(...)` (not crash) | Enumerable | spec-004 |

## A.6 Profiler Surface

| # | Item | Category | Owner Spec |
|---|---|---|---|
| 24 | Profiler `.everyFrame` overhead ≤ 0.5 ms | Performance | spec-006 |
| 25 | Profiler `.off` overhead = 0 allocations/frame | Assertable | spec-006 |
| 26 | Profiler reports FPS / dt / memory / GPU time | Assertable | spec-006 |
| 27 | Aggregator emits rolling window every 1 s | Enumerable | spec-006 |

## A.7 Build / Toolchain

| # | Item | Category | Owner Spec |
|---|---|---|---|
| 28 | `git clone && ./scripts/bootstrap.sh && open DesktopPet.xcodeproj` is one-shot | Enumerable | spec-001 |
| 29 | `swift test` passes | Enumerable | spec-001 |
| 30 | `xcodebuild test` passes | Enumerable | spec-001 |
| 31 | Cold `swift build` ≤ 90 s; incremental ≤ 5 s | Performance | spec-001 |

## A.8 Previous-Phase Regression

- N/A — Phase 1 is the origin.
