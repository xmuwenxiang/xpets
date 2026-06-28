# Architecture

> Top-level architecture documentation. Architecture docs describe the **system**: how modules relate, threading model, render pipeline, AI Runtime flow.
>
> Detailed **module** contracts live in `api/`. Detailed **artifacts** contracts live in `assets/`. Detailed **design alternatives** live in `decisions/`.

---

## Contents

| File | Purpose |
|---|---|
| `overview.md` | Layered architecture (AI Layer / Runtime Layer / Engine Layer) — reading order step 1 |
| `v1-design.md` | **Historical** Architecture Specification V1 (preserved for traceability; superseded by Phase 2+) |
| `threading-model.md` | Threads, queues, locks, IPC boundaries |
| `render-pipeline.md` | Metal frame graph, pass order, shader stages |
| `ai-runtime.md` | Claude CLI ↔ Runtime Intent ↔ Skill execution flow |
| `lifecycle.md` | Launch → Boot → Idle → Sleep → Shutdown state machine |
| `desktop-overlay.md` | Transparent window, layer, click-through, multi-display |

---

## Reading Order

1. `overview.md` (start here — system layer diagram)
2. `v1-design.md` (the historical Architecture Spec V1, kept for context — current system follows Phases 1–9 in `roadmap.md`)
3. `lifecycle.md`
4. `threading-model.md`
5. `render-pipeline.md`
6. `ai-runtime.md`
7. `desktop-overlay.md`

---

## Status

This directory is **scaffolded**. `overview.md`, `threading-model.md`, `lifecycle.md`, `render-pipeline.md`, `ai-runtime.md`, `desktop-overlay.md` are stubbed with section headers; full content fills as Phases progress.

`v1-design.md` is **preserved historical content** — unchanged from the original Architecture Spec V1 by Xavier Zhang. See `specs/_legacy/specs-v1-44-spec-DEPRECATED.md` for the v1 SPEC list and `specs/_legacy/migration-map.md` for the v1 → v2 mapping.

See `specs/` for the actionable work plan and `specs/Phase-N-*/overview.md` for the per-Phase deliverables.
