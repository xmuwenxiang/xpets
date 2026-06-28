# Phase 5 — Desktop World

> **Status**: Stub — Phase 4 closure gating begins content authoring.
> **Goal**: Make the desktop a 3D world. Dock, Finder windows, Widget, Desktop icons, Menu Bar — all become entities the fox can interact with.
> **Primary Output**: The fox hops onto the Dock, walks around desktop icons, peeks into Finder windows, and (per Privacy Spec Phase 6) reads but does not react to certain sensitive content.

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 4 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 5 start.

> **Internal sub-phase split (D-005)**:
> - **5a — Desktop Discovery**: enumerate desktop entities, define abstractions, **decide world-rendering route** (single / dual / native capture), define visibility policy.
> - **5b — Desktop World**: container, collision, NavMesh, Pet interaction, integration of Phase 3 / 4 reservation hooks.

---

## Goal (Phase 5 final)

A 3D virtual mirror of the desktop exists. The fox navigates it via NavMesh, respects invisibility / privacy boundaries, and exhibits different behaviors per desktop region.

---

## Pre-known Deliverables (to be expanded)

- `spec-001-desktop-discovery.md` — Entity catalog, abstraction, privacy visibility policy (D-005)
- `spec-002-world-rendering-route.md` — Decision on World rendering path (D-005)
- `spec-003-world-events.md` — WindowChange, AppSwitch, ScreenChange event sources
- `spec-004-desktop-world.md` — Container, collision, NavMesh, Pet interaction
- Cross-delivers Animation Driver interface real implementation (D-007) for Phase 6 use

---

## Phase 5 Internal Split (D-005)

### Phase 5a — Desktop Discovery
- Entity inventory: Dock / Finder / Widget / Desktop Icon / Menu Bar / Notification / Active Window
- Abstraction: every entity carries `position`, `bounds`, `collisionLayer`, `visibilityClass`
- **Decision tree (D-005)**: Single Renderer vs Dual Renderer vs Native Capture — must close here
- Privacy visibility contract (deferred specifics to Phase 6 Privacy Spec)

### Phase 5b — Desktop World
- Container & collision integration with Phase 3 Collider-Edge hook
- NavMesh implementation (SPEC-020 legacy mapping)
- Pet interaction: hop-onto-Dock, walk-around-icons, peek-into-Finder

---

## Out of Scope (Phase 5)

- ❌ Pet decision-making (where to walk) — Phase 6
- ❌ Pet emotional response to entity type — Phase 6
- ❌ Claude integration — Phase 7

---

## Risk (placeholder)

- macOS Accessibility permission grants
- Multi-display state drift
- WindowList snapshot staleness
- Pet entering a Window without breaking the user's UI

---

## Acceptance (placeholder — 4 categories)

- Dock / Finder / Widget entities detected and abstracted
- Pet hops onto Dock within N frames
- NavMesh detects widget obstacle and reroutes around it
- Privacy visibility policy enforced (excludes OCR of certain regions)

---

## Cross-References

- Phase 1: Window subsystem
- Phase 2: Renderer (rendering-route decision D-005)
- Phase 3: Collider-Edge hook (D-003)
- Phase 4: Animation Driver hook (D-003 / D-007)
- Phase 6: Privacy Spec boundaries
