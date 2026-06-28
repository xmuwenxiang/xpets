# Roadmap (Phase-Based, v2)

> The authoritative 10-Phase delivery plan for the AI Native 3D Desktop Pet.
> This document is the **single source of truth** for Phase ordering, scope, and decision traceability.
> **Last updated**: 2026-06-28.
> **Related historical doc**: `architecture/v1-design.md` (preserved).

---

## 1. Decomposition Rationale

The previous (legacy) decomposition used 15-Phases × 44-Specs in module-topology order (see `architecture/v1-design.md`). This created severe cross-Phase dependency churn:

```
Renderer → Scene → Physics → Resource → AI
   ↑        ↑        ↑                    ↑
   └─ Renderer 依赖 Scene
            └─ Scene 依赖 Physics
                       └─ Physics 依赖 Resource
                                          └─ AI 依赖 Runtime
```

We rebased to **9 milestone-based Phases** aligned with how Apple (FoundationDB, Swift), Google (Fuchsia), Unity, and Godot organize their public roadmaps: each Phase is a *vertically integrated* sprint that ships a runnable artifact.

See also: `architecture/v1-design.md` for the v1 architecture rationale (kept for traceability). All v3+ timing details (FPS budgets, memory budgets, math) trace through `roadmap.md` and the ADR set in `decisions/`.

---

## 2. The 9-Phase Plan

| Phase | Name | Goal | Primary Output |
|---|---|---|---|
| 1 | **Foundation** | Boot, window, runtime loop, asset, animation, profiler | `DesktopPet.app` displays fox at 60 FPS |
| 2 | **Rendering** | PBR, lighting, shadow, camera, HDR | Fox self-renders with realism |
| 3 | **Physics** | Jolt, gravity, collision, spring (tail), collider-edge hook | Fox jumps / lands / tail wags |
| 4 | **Animation** | Blendtree, 4 IK variants (D-012), random idle, layer, animation-driver hook | Polished motion + head/ear/foot IK |
| 5 | **Desktop World (5a + 5b)** | 5a = Desktop Discovery (entity catalog + render-route decision). 5b = World container + NavMesh + Pet interaction | Fox hops onto Dock |
| 6 | **Behavior** | Utility AI, emotion, memory, daily routine + **privacy boundaries** (D-006) | Living, ethical fox |
| 7 | **AI** | Claude CLI, tool calling, intent, skill runtime + **failure mode matrix** (≥5 scenarios) | Fox talks back |
| 8 | **Hardening** | CPU/GPU/battery/memory/package optimization (D-009) | <100MB runtime, <30MB installer |
| 9 | **Beta** | Reliability (auto-update / crash / telemetry) + Ecosystem (plugin / marketplace) | Shipped product |

> Numeric IDs (1..9) are **frozen** — adding a Phase is append-only. Phase 5 internally splits 5a / 5b but the Phase directory stays `Phase-5-DesktopWorld/`. Phase 9's Reliability + Ecosystem halves split as **Work Specs**, not separate Phases.

---

## 3. Decisions Locked (D-001 .. D-013)

These decision IDs are frozen at this roadmap revision. Future changes require new ADRs in `decisions/`.

| ID | Decision | Source |
|---|---|---|
| **D-001** | 9-Phase milestone decomposition supersedes 44-Spec module decomposition | Decomposition Rationale §1 |
| **D-002** | TDD enforced — every Work Spec must ship with unit + integration tests authored test-first | Convention §3.2 deliverable-binding rule |
| **D-003** | Phase 3 + Phase 4 must carry `World Integration Reservation` for Phase 5 hooks (Collider-Edge + Animation-Driver) | Review iteration 2 |
| **D-004** | Animation asset format fixed at Phase 1: Skeleton + Animation **embedded in .glb** | Review iteration 2 |
| **D-005** | Phase 5 internal split (5a / 5b) without Phase renumbering | Review iteration 2 |
| **D-006** | Phase 6 = local Behavior Runtime, no LLM dependency; Skill concept is stubbed in Phase 6, real runtime in Phase 7 | Review iteration 2 |
| **D-007** | Phase 5 must cross-phase-deliver Animation Driver subsystem early so Phase 6 development is not blocked | Review iteration 2 |
| **D-008** | Continuous Profiling bootstrapped in Phase 1 (`spec-006-profiler.md`); every Phase Acceptance carries a Performance-budget line | Review iteration 2 |
| **D-009** | Phase 8 renamed to `Hardening` (formerly "Optimization") | Review iteration 2 |
| **D-010** | Apple Spec style (Goal / Deliverables / Out Of Scope / Risk / Acceptance) is the only Phase/Work Spec template | `specs/00-spec-conventions.md` |
| **D-011** | Legacy `specs-v1-44-spec-DEPRECATED.md` retained for traceability, never authoritative | `archival policy` |
| **D-012** | Phase 4 IK scope fixed: Two-Bone (ears), CCD (tail), Foot (legs), Look-At (head/eyes) | Review iteration 2 |
| **D-013** | Every Phase Acceptance must include 4 categories: Performance metrics, Enumerable cases, Assertable states, Previous-Phase regression | Review iteration 2 / `00-spec-conventions.md` §3.5 |

---

## 4. Phase Identification

- Phase 1..9 numeric identifiers are **frozen** — no Phase will be renumbered.
- Adding a Phase = append a new number; refactoring an existing Phase = new ADR + amendment.
- Phase 5 sub-identifier (5a, 5b) is internal-only; the Phase dir is `Phase-5-DesktopWorld/`.

---

## 5. Cross-Phase Dependencies

```
Phase 1 (Foundation) → no upstream
Phase 2 (Rendering) → Phase 1 [Window, Asset]
Phase 3 (Physics)   → Phase 1 [Skeleton]
                       MUST reserve Collider-Edge hook (D-003), implemented in Phase 5
Phase 4 (Animation) → Phase 1 [Animation]
                       MUST reserve Animation-Driver hook signature only (D-003)
                       Real implementation: cross-delivered by Phase 5 (D-007) — Phase 4 ships NO implementation
Phase 5a            → Phase 1/2/3/4 [vertically integrates for first time]
Phase 5b            → Phase 5a + the Collider-Edge hook from Phase 3 + Animation-Driver hook from Phase 4
Phase 6 (Behavior)  → Phase 4 [Animation Layer driver]
                       Phase 5 [advances Animation-Driver interface per D-007]
Phase 7 (AI)        → Phase 6 [Skill stub]
Phase 8 (Hardening) → no upstream; whole-system pass
Phase 9 (Beta)      → Phase 1..8 → Reliability subset MUST ship; Ecosystem subset may defer to v1.1
```

> Note on D-007: cross-deliverable owner is Phase 5. Phase 4 only **reserves the method signature** for Phase 5 to fill — see `specs/Phase-4-Animation/overview.md` World Integration Reservation, and `00-spec-conventions.md` §5.

---

## 6. Milestone Mapping (Legacy → v2)

The legacy `specs/_legacy/specs-v1-44-spec-DEPRECATED.md` defined M1..M5. The v2 mapping is:

| Legacy Milestone | v2 Phases |
|---|---|
| M1 (transparent window, GLB, basic animation) | **Phase 1** (Foundation) |
| M2 (Physics, PBR, Shadow, behavior) | **Phase 2 + 3 + 4** |
| M3 (Claude CLI, Skill, Memory, Chat) | **Phase 7 + part of 6** |
| M4 (Desktop World, NavMesh, full AI Runtime) | **Phase 5 + 6** |
| M5 (Beta, perf, installer) | **Phase 8 + 9** |

Per-legacy-SPEC destination: see `specs/_legacy/migration-map.md`.

---

## 7. Acceptance Discipline

Every Phase's `overview.md` closes with an Acceptance block obeying `00-spec-conventions.md` §3.5 (D-013). Every prior-Phase regression must be re-asserted in the next Phase's Acceptance.

---

## 8. Status

This roadmap is **Active**. It is amended only via ADRs in `decisions/`.

---

## 9. Phase Closure Log

| Phase | Closed on | Closure commit / gate | Notes |
|---|---|---|---|
| **1 — Foundation** | **2026-06-28** | local `d4d974b` (root) pushed; CI `168efa6` (ADR-glob fix) gave second-run green | All Work Specs `Status: Done`. Frozen for Phase 2 regression. `checklist.md` Open items: Phase 2 owner readiness sign-off, Project owner sign-off, git tag `phase-1-foundation`. |

> Phase 1 functional close vs procedural close: technical work (CI green, ADR consistency, perf budgets) closed on 2026-06-28. The three procedural items — Phase 2 owner readiness, Project owner (Xavier Zhang) sign-off, and git tag — are intentionally deferred to the next planning loop. Phase 2 Work Spec authoring can proceed in parallel; see `specs/README.md` §2 for current Phase status.
