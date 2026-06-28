# Architecture Overview

> Layered architecture diagram for the AI Native 3D Desktop Pet. The system is **vertically decomposed into 9 Phases** (see `roadmap.md`) and **structurally decomposed into three layers** as below.

---

## The Three Layers

```
┌────────────────────────────────────────────────────────┐
│                       AI Layer                          │
│  Claude CLI · Intent RPC · Skill Runtime · MCP Bridge   │
│  (Phase 7)                                              │
└────────────────────────┬───────────────────────────────┘
                         │ Intent / Skill call
┌────────────────────────▼───────────────────────────────┐
│                    Runtime Layer                         │
│  Behavior · Navigation · Physics · Animation             │
│  Memory · Personality · Privacy Boundaries               │
│  (Phases 3, 4, 6, 7)                                    │
└────────────────────────┬───────────────────────────────┘
                         │ Update + Render / Resolution
┌────────────────────────▼───────────────────────────────┐
│                    Engine Layer                          │
│  Renderer · Scene · Window · Asset · Profiler            │
│  (Phases 1, 2, 5)                                       │
└────────────────────────────────────────────────────────┘
```

---

## Layering Rules

- **Engine Layer** never imports Runtime Layer or AI Layer types.
- **Runtime Layer** consumes Engine Layer via the API surface (`api/` directory).
- **AI Layer** emits Intent and Skill calls; it does NOT mutate state directly.
- Modules inside one layer may import sibling-layer modules but **never** reach upward.

---

## Historical Snapshot

The v1 design (`architecture/v1-design.md`) predates the Phase decomposition. It captures the same three-layer structure but in prose form. Current implementation follows the v2 Phases; the v1 doc is preserved for traceability.

---

## Subsystem Cross-References

| Subsystem | Doc | Phase Owner |
|---|---|---|
| Lifecycle (Boot → Shutdown) | `lifecycle.md` | Phase 1 |
| Threading (queues, fences, IPC) | `threading-model.md` | Phase 1 + Phase 7 |
| Render Pipeline (Metal passes) | `render-pipeline.md` | Phase 2 |
| Live World (Desktop entities) | `desktop-overlay.md` | Phase 5 |
| AI Runtime (Claude ↔ Intent ↔ Skill) | `ai-runtime.md` | Phase 7 |
| Module Layout | `module-layout.md` | Phase 1 |
| Layer Map | `overview.md` (this file) | — |
| v1 design (historical) | `v1-design.md` | — |

---

## Status

**Active**. Authoritative for layering rules; Phase-linked subsections filled as phases land.
