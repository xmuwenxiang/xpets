<!--
Status: Draft
Phase: 5a — DesktopWorld
Owner: TBD
Depends: Phase 2 spec-001-metal-renderer.md
-->

# SPEC-001 — Desktop Discovery (Entity Catalog + Visibility Contract)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Catalog enumerates macOS desktop entities into a typed list with a forward-compatible **visibility contract**. The visibility **mapping** (which app/window → which class) is reserved for **Phase 6 Privacy Spec**; Phase 5 ships the data model only.

---

## 1. Goal

Build a typed, observable catalog of desktop entities (Dock, Finder windows, Widget, Desktop icons, Menu Bar, Notification, Active Window) with `(position, bounds, collisionLayer, visibilityClass)` per entity, driven by AppKit / Accessibility / CoreGraphics introspection. After SPEC-001 ships, subscribed components (Phase 5b NavMesh, Phase 6 Behavior) can read the entity catalog as a stable data source.

---

## 2. Deliverables

- `DPDesktop.Entity` value type:
  - `id: Entity.ID` (deterministic from window-id or stable-hash).
  - `kind: EntityKind` (`.dock | .finderWindow | .widget | .desktopIcon | .menuBar | .notification | .activeWindow`).
  - `position: SIMD3<Float>`, `bounds: SIMD4<Float>` (x, y, z, depth).
  - `collisionLayer: Collider.CollisionLayer` (`.defaultLayer | .edge` from Phase 3).
  - `visibilityClass: VisibilityClass = .public` (default; `.private` and `.sensitive` usable).
- `DPDesktop.EntityCatalog`:
  - `var entities: [Entity.ID: Entity]`.
  - `subscribe(handler:)` for `EntityChange` events (added/updated/removed).
  - Snapshot throttle ≤ 1 Hz; deltas delivered immediately.
- Discovery sources:
  - `NSScreen.windows`, `NSWorkspace.didActivateApplicationNotification`, `CGWindowList` (with permission).
  - Accessibility tree (with permission): permission allows widget / dock detection without OCR.
- Graceful-degradation: missing permissions → catalog has zero entities; UI surfaces a permission prompt (Phase 6 owns the prompt).
- **Tests** (TDD per D-002):
  - Unit: synthetic catalog with 10 entities; subscribe handler receives 10 added events.
  - Unit: entity bounds update via `WindowChange` event; handler receives 1 updated event.
  - Unit: entity removal (window closed); handler receives 1 removed event.
  - Unit: snapshot throttle: 60 simulated `tick(dt:)` events within 1 s produce exactly one snapshot (1 Hz).
  - Permission-denied path: Catalog reports `isAuthorized == false` and entities are empty.
- **API docs**: `api/entity-catalog-api.md` — `Entity`, `EntityKind`, `EntityChange` types; thread-model; permission gate.

---

## 3. Out of Scope

- ❌ Privacy visibility **mapping** (which entity gets `.sensitive`) — Phase 6.
- ❌ Behavior / decisions on entity type — Phase 6.
- ❌ NavMesh — `spec-004-desktop-world.md`.
- ❌ Pet interaction — `spec-004-desktop-world.md`.

---

## 4. Risk

- **macOS Accessibility permission grants** — Mitigation: Phase 5 ships "denied" path; UI prompt deferred to Phase 6.
- **CGWindowList returns hidden windows** (window flags include `kCGWindowName == nil`) — Mitigation: filter such windows from the catalog by default; Phase-6 Privacy Spec may opt back in.
- **Multi-display state drift** — Mitigation: subscribe to `NSApplication.didChangeScreenParametersNotification`; recompute `bounds` per display.
- **Stale WindowList** — Mitigation: 1 Hz snapshot throttle + delta events.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Catalog snapshot refresh ≤ 16 ms at 60 FPS on M2 with ~100 entities in flight.
- Memory delta ≤ 3 MB on top of Phase-4 baseline.
- Snapshot events delivered at ≤ 1 Hz aggregate; per-entity delta events bypass throttle.

### Enumerable use case

- 10 synthetic entities: subscribe → 10 added events received.
- 1 entity bounds update: 1 updated event received.
- 1 entity removal: 1 removed event received.
- 60 simulated ticks in 1 s: exactly 1 snapshot delivered (the rest are deltas).
- Permission denied: catalog reports `isAuthorized == false` and entities map is empty.

### Assertable state

- `Entity.id` is deterministic: re-running the catalog discovery over an unchanged window list produces the same `Entity.ID` for the same logical window.
- `visibilityClass` defaults to `.public`; Phase 6 may set to other classes via a `(setter)` API.
- `EntityCatalog` is thread-safe via `Sendable` snapshot; mutations delivered via event channel.
- Snapshot throttle assertion: timer-based test asserts the time-between-snapshots is ≥ 0.99 s (1 Hz).

### Previous-Phase regression

- Phase 1..4 `acceptance.md` items still pass.
- Phase-3 `CollisionLayer` (back-deps in `Collider.collisionLayer: .edge`) is consistent — Phase 5 maps Dock / Menu Bar to `.edge` per Phase-3 reservation.
- Profiler `.everyFrame` budget unchanged.
