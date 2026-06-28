<!--
Status: Drafts authored (2026-06-28)
Phase: 5 — DesktopWorld (5a + 5b)
Owner: TBD
ADRs:  D-003 (consume Phase 3 Collider-Edge + Phase 4 AnimationDriver reservations), D-005 (5a/5b internal split), D-007 (Phase 5 cross-delivers AnimationDriver implementation), D-008, D-013
-->

# Phase 5 — Desktop World

> **Status**: Stub → **Drafts authored (2026-06-28)**. Four Work Specs now exist at Apple Style + 4-category Acceptance; implementation gated on owner review + `Status: Approved`.
> **Goal**: Make the desktop a 3D world. Dock, Finder windows, Widget, Desktop icons, Menu Bar — all become entities the fox can interact with.
> **Primary Output**: The fox hops onto the Dock, walks around desktop icons, peeks into Finder windows, and (per Privacy Spec Phase 6) reads but does not react to certain sensitive content.

> **Internal sub-phase split (D-005)**:
> - **5a — Desktop Discovery**: enumerate desktop entities, define abstractions, **decide world-rendering route** (single / dual / native capture), define visibility policy.
> - **5b — Desktop World**: container, collision, NavMesh, pet interaction, integration of Phase 3 / 4 reservation hooks.
>
> **Per D-007**, Phase 5 **cross-delivers the AnimationDriver implementation** that Phase 4 reserved as signature-only.

---

## 1. Goal (Phase 5 final)

A 3D virtual mirror of the desktop exists. The fox navigates it via NavMesh, respects invisibility / privacy boundaries, and exhibits different behaviors per desktop region. The world is **not** a UI overlay of macOS; the fox lives in a transparent 3D layer puppeteered by real-world screen geometry.

After Phase 5 closes, the fox hops onto the Dock, walks around Desktop icons, peeks into Finder windows, and respects the Phase-6 privacy visibility policy.

---

## 2. Pre-known Deliverables (finalized)

- [`spec-001-desktop-discovery.md`](spec-001-desktop-discovery.md) — Entity catalog, abstraction, privacy visibility contract (5a).
- [`spec-002-world-rendering-route.md`](spec-002-world-rendering-route.md) — **Single / Dual / Native Capture** decision (5a; per D-005 this is the canonical cross-Phase rendering decision).
- [`spec-003-world-events.md`](spec-003-world-events.md) — `WindowChange`, `AppSwitch`, `ScreenChange`, `DisplayConfigChange` event sources (5b).
- [`spec-004-desktop-world.md`](spec-004-desktop-world.md) — Container, NavMesh, Pet interaction, **AnimationDriver implementation** (D-007 cross-deliverable), Phase-3 `Layer.edge` integration.

---

## 3. Phase 5 Internal Split (D-005)

### Phase 5a — Desktop Discovery

- **Entity inventory**: Dock / Finder / Widget / Desktop Icon / Menu Bar / Notification / Active Window.
- **Abstractions**: every entity carries `position`, `bounds`, `collisionLayer`, `visibilityClass`.
- **Decision tree** (D-005): Single Renderer vs Dual Renderer vs Native Capture — must close here.
- **Privacy visibility contract**: defer concrete list to Phase 6 (Phase 5 ships the shell).

### Phase 5b — Desktop World

- **Container & collision**: integrates with Phase-3 `Collider.collisionLayer.edge` (consume D-003 reservation).
- **NavMesh**: surface-sampled from active windows + dock topology.
- **Pet interaction**: hop-onto-Dock, walk-around-icons, peek-into-Finder.
- **AnimationDriver implementation** (D-007 cross-deliverable): concrete `Phase5AnimationDriver` conforms to the Phase-4 protocol signature.

---

## 4. Out of Scope (Phase 5)

- ❌ **Pet decision-making** (where to walk) — Phase 6.
- ❌ **Pet emotional response to entity type** — Phase 6.
- ❌ **Claude integration** — Phase 7.

---

## 5. World Integration Reservation (D-003 + D-007 — Phase 5 as consumer)

Per **D-003** and **D-007**, this Phase is the **consumer** of two reservations seeded in earlier Phases:

1. **Phase-3 `Collider.collisionLayer.edge`** (D-003 mandatory in Phase 3). Phase 5a ships the real `Phase5EdgeBridge` implementation; Phase 3's `.noop` becomes the fallback.
2. **Phase-4 `AnimationDriver` protocol** (D-007 signature-only in Phase 4). Phase 5b ships the real `Phase5AnimationDriver` concrete type.

Both reservations are documented as **resolved** at Phase-5 closure.

---

## 6. Privacy Visibility (forward to Phase 6)

Phase 5 ships *the data model* — every entity carries `visibilityClass: .public | .private | .sensitive` — but the **mapping** of which app/window gets which class is reserved for Phase 6 Privacy Spec. Phase 5 does NOT yet decide what is sensitive; it only provides the contract.

---

## 7. Risk (placeholder — to be expanded at Phase-5 kickoff)

- **macOS Accessibility permission grants** — Mitigation: Phase 5 ships "denied" path (entity catalog shows minimal placeholder entities), instructs user how to grant.
- **Multi-display state drift** — Mitigation: subscribe to `NSApplication.didChangeScreenParametersNotification`; event source `ScreenChange` (see `spec-003`).
- **WindowList snapshot staleness** — Mitigation: `WindowChange` event source drives catalog refresh; snapshot is throttled to ≤ 1 Hz.
- **Pet entering a Window without breaking the user's UI** — Mitigation: Pet's hit-test on a `Window.entity` triggers `DockHop` behavior (i.e. pet does NOT actually focus the window); boundary is enforced by event-driven interaction.
- **NavMesh dynamic topology (windows opening / closing)** — Mitigation: NavMesh rebuilds incrementally on `WindowChange`, with ≤ 16 ms refresh budget.
- **Single-Renderer vs Dual-Renderer vs Native-Capture lock-in** — Mitigation: decision is **frozen** at Phase-5a; subsequent Switch requires ADR.

---

## 8. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md). Cumulative Phase-5 memory delta target: **≤ 12 MB** on top of Phase-4 baseline (≤ 160 MB worst-case at end-of-Phase-5). Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24) unaffected.

---

## 9. Cross-References

- **Phase 1**: `spec-002-window.md` (NSWindow shape), `spec-003-runtime.md` (`TaskEvent`-style consumption pattern).
- **Phase 2**: `spec-001-metal-renderer.md` (consumed by `spec-002-world-rendering-route.md`).
- **Phase 3**: `spec-004-world-reservation.md` (Phase-5 replaces `.noop` with real `Phase5EdgeBridge`).
- **Phase 4**: `spec-004-animation-driver.md` (Phase-5 ships `Phase5AnimationDriver` conformer — D-007 cross-deliverable).
- **Phase 6**: Privacy Spec — owner of `visibilityClass` mapping.
- **ADRs**: D-003, D-005 (5a/5b split), D-007, D-008, D-013.
