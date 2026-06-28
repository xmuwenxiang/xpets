# Migration Map: Legacy v1 (44-Spec) → v2 (10-Phase)

> Companion to `specs-v1-44-spec-DEPRECATED.md`. Tells the implementer where each legacy SPEC-001..44 lives in the v2 decomposition.

---

## Reading the Map

Each row of the table below maps a legacy SPEC to its v2 destination.
Use this when porting existing outlines, references, or older designs in conversation.

| Legacy SPEC | Legacy Title | v2 Destination |
|---|---|---|
| SPEC-001 | Project Bootstrap | Phase 1 / `spec-001-bootstrap.md` |
| SPEC-002 | Window System | Phase 1 / `spec-002-window.md` |
| SPEC-003 | Runtime Architecture | Phase 1 / `spec-003-runtime.md` |
| SPEC-004 | Metal Renderer | Phase 2 |
| SPEC-005 | Resource Manager | Phase 1 / `spec-004-asset.md` |
| SPEC-006 | Material System | Phase 2 |
| SPEC-007 | Lighting | Phase 2 |
| SPEC-008 | Post Processing | Phase 2 |
| SPEC-009 | Physics Engine | Phase 3 / `spec-001-physics-engine.md` (Physics) |
| SPEC-010 | Character Physics | Phase 3 |
| SPEC-011 | Secondary Motion | Phase 3 / `spec-003-secondary-motion.md` (Spring tail) |
| SPEC-012 | Skeleton Runtime | Phase 1 / `spec-005-animation.md` (Skeleton + Idle baseline) |
| SPEC-013 | Animation System | Phase 4 / `spec-002-animation-system.md` |
| SPEC-014 | Blend Tree | Phase 4 / `spec-003-blendtree.md` |
| SPEC-015 | IK System | Phase 4 / `spec-004-ik-system.md` (4 IK types) |
| SPEC-016 | Scene Graph | Phase 5a / Phase 2 fold-in |
| SPEC-017 | Camera | Phase 2 |
| SPEC-018 | Coordinate System | Phase 5a (Desktop Space ↔ World Space) |
| SPEC-019 | Desktop Mapping | Phase 5a / `spec-001-desktop-discovery.md` |
| SPEC-020 | NavMesh | Phase 5b / `spec-002-desktop-world.md` |
| SPEC-021 | Movement Controller | Phase 5b |
| SPEC-022 | FSM | Phase 6 / `spec-001-behavior-fsm.md` |
| SPEC-023 | Utility AI | Phase 6 / `spec-002-utility-ai.md` |
| SPEC-024 | Emotion | Phase 6 / `spec-003-emotion.md` (+ Privacy Spec) |
| SPEC-025 | Claude Runtime | Phase 7 / `spec-001-claude-runtime.md` |
| SPEC-026 | IPC | Phase 7 / `spec-002-claude-ipc.md` |
| SPEC-027 | Intent Executor | Phase 7 / `spec-003-intent-executor.md` |
| SPEC-028 | Skill Runtime | Phase 6 (stub) → Phase 7 (full) / `spec-004-skill-runtime.md` |
| SPEC-029 | Built-in Skills | Phase 7 / `spec-005-builtin-skills.md` |
| SPEC-030 | MCP Bridge | Phase 7 / `spec-006-mcp-bridge.md` |
| SPEC-031 | Asset Pipeline | Phase 1 / `spec-004-asset.md` |
| SPEC-032 | Asset Cache | Phase 1 / `spec-004-asset.md` (folded) |
| SPEC-033 | Desktop Object Detection | Phase 5a / `spec-001-desktop-discovery.md` |
| SPEC-034 | World Event | Phase 5a / `spec-002-world-events.md` |
| SPEC-035 | Settings | Phase 8 (UI layer, deferred from Phase 1) |
| SPEC-036 | Chat Panel | Phase 7 / `spec-007-chat-panel.md` |
| SPEC-037 | Debug Panel | Phase 1 (basic in spec-006) + Phase 8 (full) |
| SPEC-038 | SQLite | Phase 6 (`spec-005-memory.md`) |
| SPEC-039 | Save System | Phase 6 |
| SPEC-040 | Optimizer | Phase 8 / Hardening |
| SPEC-041 | Frame Scheduler | Phase 8 |
| SPEC-042 | Auto Update | Phase 9 / Reliability |
| SPEC-043 | Crash Report | Phase 9 / Reliability |
| SPEC-044 | Telemetry | Phase 9 / Reliability |

---

## Footnotes

1. **Numbering note**: v2 Work Specs use a global NNN counter (`spec-NNN-*.md`). Legacy SPEC-001..44 numbers are NOT preserved; this avoids confusion and forces clean naming.
2. **Folder convention note**: v2 groups all files for one Phase under `Phase-N-<Name>/`, eliminating the legacy split between numbered SPEC files and Milestone grouping.
3. **Coverage note**: every legacy SPEC has at least one v2 destination. If something is unclear, the default mapping is to the Phase whose goal most directly aligns with the legacy SPEC's title.

---

## When to Update This File

- Upon opening a new Phase: confirm each migrated SPEC has a current v2 destination.
- Upon re-architecting a Phase: update the destination, leave a note, bump the file `version:`.
