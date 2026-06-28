# API

> Module public surface documentation. Each API doc specifies the contract between a module and its consumers, including signatures, invariants, error modes, and testing hooks.
>
> Architecture intent → `architecture/`. Implementation choice rationale → `decisions/`.

---

## Contents

| File | Module | Owner Phase |
|---|---|---|
| `runtime-api.md` | Desktop Runtime lifecycle (Boot/Update/Shutdown) | Phase 1 |
| `window-api.md` | NSWindow wrapper (Transparent / AlwaysOnTop / ClickThrough) | Phase 1 |
| `asset-api.md` | GLB / KTX2 loader, async loader, cache | Phase 1 |
| `animation-api.md` | Skeleton, Animation, BlendTree, IK | Phase 1 + Phase 4 |
| `renderer-api.md` | Metal renderer entry, pass registration, frame submit | Phase 2 |
| `material-api.md` | PBR material, environment, IBL | Phase 2 |
| `physics-api.md` | Jolt World, RigidBody, Collider (with Edge hook) | Phase 3 |
| `behavior-api.md` | Utility AI, FSM, Emotion, Memory | Phase 6 |
| `skill-api.md` | Skill registry, permissions, lifecycle, MCP bridge | Phase 7 |
| `claude-ipc.md` | Unix Socket / JSON-RPC / Streaming / Tool Calling protocol | Phase 7 |
| `desktop-world-api.md` | Virtual world entities (Dock, Window, Icon), NavMesh | Phase 5a / 5b |

---

## Conventions

- All API docs use **Swift** as the reference language for signatures (chosen per `decisions/D-NNN-language.md` when locked).
- Async APIs use `async/await` unless explicitly noted otherwise.
- Each API doc ends with a "Test Hooks" section enumerating how to mock the API in tests.

---

## Status

This directory is **scaffolded**. Each API file is a stub pending the corresponding Phase/Work Spec reaching `Status: Approved`.
