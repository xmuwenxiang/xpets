<!--
Status: Draft
Phase: 5a — DesktopWorld
Owner: TBD
Depends: spec-001-desktop-discovery.md, Phase 2 spec-001-metal-renderer.md
ADRs:   D-005 (Phase 5 rendering-route decision lives here), D-008, D-013
-->

# SPEC-002 — World Rendering Route (Decision)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **D-005 makes this canonical decision live in Phase 5a, not in Phase 2.** Single / Dual / Native-Capture is locked here. The decision is irreversible without an ADR.

---

## 1. Goal

Lock in the world rendering path — how the fox's 3D layer composites with the actual desktop contents. After SPEC-002 ships, the Phase-2 Renderer (Phase 2 spec-001) is configured with the chosen route via a `Renderer.worldConfig` typed struct; Phase 5b `spec-004-desktop-world.md` consumes this configuration.

---

## 2. Deliverables

- `enum WorldRenderingRoute`:
  - `.singleRenderer` — Phase-2-camera is the only renderer; the desktop UI is composited *behind* the renderer via NSWindow level management.
  - `.dualRenderer` — separate renderer for the world (5b) and one for the desktop reflection (mapped entity surfaces); tile-based composite via Metal MPS.
  - `.nativeCapture` — capture the desktop via `CGWindowListCreateImage` and texture it as the world background; the fox is a foreground sprite over real desktop pixels.
- **Decision tree** is `FrozenAtImpleTime`; once a route is selected, the only way to change it is via ADR.
- `DPRenderer.Renderer.worldConfig: WorldRenderingRouteConfig?` — typed config: `{ route:, routeSpecificParams }`. Set by Phase-5a boot sequence; read-only afterwards.
- **Default** in Phase 5 spec authoring is **`.singleRenderer`** (recommended by draft; subject to owner override at Phase-5a kickoff). The default is `DPFoundation.Config.defaultWorldRoute = .singleRenderer`.
- Tests:
  - Unit: `WorldRenderingRoute` is an `enum` with three cases; switch is exhaustive.
  - Unit: setting `.singleRenderer` writes the config field; immutable after subsequent setter attempt.
  - Unit: setting route to `.dualRenderer` produces a `Renderer.worldConfig.route == .dualRenderer`.
  - Integration: Phase-2 Renderer accepts the config (assertable type compatibility).
- **API docs**: `api/world-rendering-route-api.md` — explicit enum documentation, immutability rule, ADR path for changes.

---

## 3. Out of Scope

- ❌ **Per-app rendering rules** (e.g. we want Native Capture for Safari but Single for Finder) — out of Phase 5; reserved for post-Phase-9 if needed.
- ❌ **GPU compute-based reflection** — Phase 8.
- ❌ **Multi-Pet split-rendering** — post-Phase-9.

---

## 4. Risk

- **Wrong default (`.singleRenderer` chosen but `.nativeCapture` suits)** — Mitigation: the default is a draft proposal; Phase-5a kickoff explicitly reviews this. The decision tree depends on **Foundation accessibility permission granted = full-fidelity; denied = `.nativeCapture`**. Owner may lock-in `.nativeCapture` if permissions are unfixable.
- **`.dualRenderer` GPU overhead** — Mitigation: dual-renderer is the most expensive; budget for it is 1.5x Phase-2 worst-case (180 MB memory); tested under Phase-8 Hardening.
- **`.nativeCapture` OCR / privacy issues** — Mitigation: capture is *image* not *text*; OCR is forbidden at Phase-5 level; enforced by a layering rule: Phases cannot introduce OCR.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Configuration storage cost ≤ 64 bytes (one enum + optional struct).
- No runtime tick cost (config is set-once at boot).
- Memory delta ≤ 0.1 MB on top of Phase-4 baseline.

### Enumerable use case

- Boot with default `DPFoundation.Config.defaultWorldRoute = .singleRenderer`.
- Override at boot: `config.worldRoute = .dualRenderer` — `Renderer.worldConfig.route == .dualRenderer` after boot.
- `.nativeCapture` override — same.
- After boot, attempting to mutate the config throws `RendererError.configImmutable` (immutability rule).

### Assertable state

- `WorldRenderingRoute` is an exhaustive `enum`.
- `Renderer.worldConfig` is `let` (immutable after boot).
- `WorldRenderingRouteConfig` is `Codable` — config persists across launches.

### Previous-Phase regression

- Phase 1..4 `acceptance.md` items still pass.
- Phase-2 Renderer architecture unchanged (config is a setter / getter hook only).
- Profiler `.everyFrame` budget unchanged.
