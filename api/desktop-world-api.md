# Desktop World API

> Phase: 5 (Desktop World, 5a + 5b)
> Related: `architecture/desktop-overlay.md`, D-005

---

## Public Surface (Phase 5a)

```
public enum WorldEntity {
    case dock
    case finder
    case widget
    case desktopIcon
    case menuBar
    case notification
    case activeWindow
}

public protocol WorldEntityDescriptor {
    var id: UUID { get }
    var bounds: CGRect { get }
    var collisionLayer: CollisionLayer { get }  // reserved for D-003 (Edge)
    var visibilityClass: VisibilityClass { get }
}

public final class WorldDiscovery {
    public init()
    public func discover() -> [any WorldEntityDescriptor]
    public func subscribe(_ observer: @escaping (WorldEvent) -> Void)
}
```

## Phase 5b additions

- `WorldContainer`, `NavMesh`, `PetInteractor`.
- Per-entity collision registration (uses Phase 3 Collider-Edge hook).
- AnimationDriver hook usage (Phase 6 onwards).

## Render-Route Decision (5a ownership)

Single / Dual / Native-capture routes settled in `spec-NNN-world-rendering-route.md`. Stub holds placeholders.

## Status

**Stub**. Phase 5a ships discovery; Phase 5b ships world container + nav.
