# D-001 — 9-Phase Milestone Decomposition

## Status
Accepted · 2026-06-28

## Context
The v1 plan (`architecture/v1-design.md`, also `specs/_legacy/specs-v1-44-spec-DEPRECATED.md`) used 15 module-based Phases × 44 Specs. In practice this caused cross-Phase dependency churn during implementation: Renderer → Scene → Physics → Resource → AI. Engineers jumped between non-adjacent Phases constantly, and AI coding tools (Claude Code, Cursor, Gemini CLI) struggled to consume the spec corpus as input.

## Considered Alternatives
- **A.** Continue with module-based 44-Spec plan; resolve conflicts by ordering rules only.
- **B.** Adopt Chromium/Swift/Godot/Unity-style milestone-based Phase decomposition; regroup work into vertically integrated chunks. **← Chosen.**
- **C.** Adopt Linear/Anthropic "Spec-as-PR" format; one Spec per PR regardless of module.

## Decision
Adopt **9 milestone-based Phases** ordered by Sprint cohesion, not module topology. Each Phase ships a runnable artifact.

## Rationale
- Each Phase boundary is a verifiable artifact (cold start to first frame, then PBR, then physics, …) — measurable without leaving the Phase.
- Reduces the cross-Phase import graph density: Phases 3 / 4 carry reservations instead of taking dependencies.
- Aligns with industry references (Apple Foundation DB, Swift evolution, Unity release notes). AI tools can consume one Phase at a time as autonomous task input.

## Consequences
- (+) Reduced blocking implementation churn; faster per-Phase close-out.
- (+) AI-driven development tools gain clear Sprint boundaries.
- (–) Some Specs (e.g. Settings UI, SQLite) get pushed to later Phases.

## Trace
- roadmap §3, §5
- Supersedes: legacy SPEC-001..44 mapping in `specs/_legacy/migration-map.md`
- Specs affected: all `specs/Phase-N-*` directories
