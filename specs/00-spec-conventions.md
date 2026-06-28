# Spec Conventions (v2 — Phase-Based)

> Authoritative spec-writing convention for the entire project. All Phase and Spec files MUST conform to this document. If a Phase file conflicts with this one, this document wins until amended.

---

## 1. Why This Document Exists

We are building an AI Native Desktop Pet **Runtime / Engine**, not a regular app. Because modules cross-cut heavily (Renderer ↔ Scene ↔ Physics ↔ Resource ↔ AI), module-based Spec 001~044 caused constant phase-jumps during development.

We adopted **10-Phase milestone-based decomposition**, aligned with Apple, Google, Unity, Godot, and large engineering organizations.

This file pins the writing style so that any AI coding tool (Claude Code, Cursor, Gemini CLI) reads these Specs uniformly.

---

## 2. The Two Spec Levels

| Level | Path Pattern | Author | Audience | Granularity |
|---|---|---|---|---|
| **Phase Spec** | `specs/Phase-N-<Name>/overview.md` | Phase owner | All engineers + AI tools | What this Sprint delivers |
| **Work Spec** | `specs/Phase-N-<Name>/spec-NNN-<slug>.md` | Spec author | Implementer + reviewer | Single deliverable in one Phase |

Rules:
- A **Phase** represents one Sprint (a milestone that compiles + runs).
- A **Work Spec** is one cohesive unit of work inside the Phase — typically one PR.
- Phase Spec Acceptance criteria MUST be satisfied when the Sprint ends.

---

## 3. Work Spec Template (Apple Style)

Every Work Spec file **MUST** use the following five sections **in this order**:

### 3.1 Goal
One paragraph (3–5 sentences) stating what capability ships when this Spec is done. Phrased in user-observable terms where possible.

### 3.2 Deliverables
A bulleted list of concrete, verifiable artifacts:
- Modules / classes added
- API surfaces exposed
- Tests authored (TDD is enforced — see `decisions/D-002-tdd.md`)
- Documentation updated
- **For Phase 1 only**: profiling instrumentation bootstrapped (D-008)

### 3.3 Out of Scope
A bulleted list of things this Spec explicitly does NOT touch. This guards against scope creep. Every Work Spec **MUST** have this section — even if empty, write "None."

### 3.4 Risk
A bulleted list of failure modes and their mitigations:
- Technical risk (e.g. Metal init failure on Apple Silicon)
- Performance risk (e.g. Spec-NNN exceeds its frame budget)
- Compatibility risk (e.g. macOS Sonoma NSWindow layer change)
- Process risk (e.g. dependency on Phase N-1 frozen APIs)

### 3.5 Acceptance — (D-013)

Per **D-013**, every Work Spec Acceptance block **MUST** be partitioned into four categories. Each item falls into at least one:

| Category | Example |
|---|---|
| **Performance metric** | Idle CPU ≤ 1 %, GPU ≤ 5 %, frame time ≤ 16.7 ms, cold start ≤ 1 s |
| **Enumerable use case** | Tail swing at 30° / 60° / 90° must converge in ≤ N frames |
| **Assertable state** | Left-turn 90° must traverse ≥ 3 blendtree intermediate states (no single-frame hard cut) |
| **Previous-Phase regression** | All Phase K Acceptance criteria still pass after Phase K+1 ships |

**Every Acceptance item MUST be objectively observable** — no subjective language (avoid: "looks good", "feels right", "responsive enough"). Use measurable equivalents ("perceived smoothness" → "dropped frame count ≤ 1 / minute").

Whenever specifying a one-sided threshold, use the Unicode symbol `≤` (NOT `<=`), e.g. `≤ 50 MB`, `≤ 1.0 s`, `≤ 30 ms`. This convention is consistent across all Spec files.

---

## 4. Phase-Level Template

Phase `overview.md` files MUST contain:

1. **Goal** — what ships at Phase close, in user-visible terms.
2. **Deliverables** — list of Work Specs in this Phase.
3. **Out of Scope** — capabilities reserved for later Phases.
4. **World Integration Reservation** — only for Phase 3 and Phase 4 (D-003). Each reserves the hooks for later Phase 5 hookups (Collider-Edge + Animation Driver).
5. **Risk** — including cross-Phase risks.
6. **Acceptance** — distilled from all Work Spec Acceptance, plus the full 4-category requirement.

### 4.1 Optional file: `acceptance.md`

For Phases with many Work Specs, a separate `acceptance.md` file lists all acceptance criteria in one place (for tricky E2E demos).

### 4.2 Optional file: `checklist.md`

A bulleted pre-flight checklist used during the Phase close-out review (CI green, docs updated, perf budget honored, regression baseline frozen).

---

## 5. Cross-Phase Hooks (D-003, D-007)

Two Work Specs **MUST** carry an explicit `World Integration Reservation` section, even when their Phase does not yet integrate with Desktop World:

| Owner Work Spec (Phase 3) | Required extension |
|---|---|
| Phase 3's World Integration Reservation Work Spec (file name selected at Phase 3 start; an example candidate is `spec-NNN-world-reservation.md`, but **the canonical Phase 3 deliverable is the Physics-Engine Work Spec itself**, which embeds the reservation) | `Collider.collisionLayer` MUST be extendable to `Layer.edge` for future Dock / Window edge collisions |

| Owner Work Spec (Phase 4) | Required extension |
|---|---|
| Phase 4's Animation Work Spec (file name selected at Phase 4 start; candidate: `spec-NNN-world-reservation.md` — same caveat as Phase 3 applies) | `AnimationDriver` MUST expose a public `(Bone, WorldPoint) -> apply(offset)` hook for Phase 5 reach-and-grab interactions |

> Per **D-007**, the **real implementation** of the Animation-Driver hook is **cross-delivered by Phase 5**, not Phase 4. Phase 4 only ships the **method signature** (a Swift protocol method stub). Implementation in Phase 5.

These reservations are not implemented in Phase 3/4 — they are *reserved interface surfaces*. Implementation happens in Phase 5.

---

## 6. Spec File Naming

- Phase directories: `Phase-N-<ShortName>/` (1, 2 — see `roadmap.md`)
- Work Specs: `spec-NNN-<kebab-slug>.md` where NNN is a zero-padded 3-digit sequence unique across the entire project (do NOT restart per Phase)
- Files in `specs/`: zero-prefixed (`00-spec-conventions.md`, `00-glossary.md`, `01-...`) for top-level utility docs

NNN sequences are allocated lazily — pick the next free number when you start authoring a Spec.

---

## 7. Status Tags

Each Work Spec file should carry a top-of-file status tag:

```
Status: Draft | In Review | Approved | Implementing | Done | Deferred
```

`Approved` is the gate to begin implementation. **D-002 (TDD)** requires that each Work Spec's Tests be authored before source code; the Status transition Approved → Implementing is only valid once at least one failed test exists for the first deliverable.

---

## 8. Traceability

Every Work Spec must reference, where applicable:

- The Phase roadmap: `specs/Phase-N-<Name>/overview.md`
- Top-level architecture docs it implements: `architecture/<file>.md`
- API docs that depend on it: `api/<file>.md`
- ADRs it implements: `decisions/D-NNN-<slug>.md`

This bidirectional trace allows AI coding tools to "read spec → find ADR → find API doc → code" without guesswork.

---

## 9. Review Gates

A Phase closes when:
1. All Work Specs in that Phase have `Status: Done`.
2. Phase overview's Acceptance items all pass objectively.
3. `checklist.md` items all checked.
4. The next Phase's World Integration Reservation (if any) is honored — verified by the Phase owner.

---

## 10. Forbidden Practices

- ❌ Writing Spec without `Out of Scope` (or with "TBD").
- ❌ Vague Acceptance ("works correctly", "looks fine").
- ❌ Cross-Phase dependencies not flagged in reservation.
- ❌ Modifying older Phase Specs after Phase close except for typo fixes (use a new Spec referencing the original instead).
- ❌ Adding a Phase without updating `roadmap.md`.

---

## 11. Amendment Process

Changes to this `00-spec-conventions.md` are themselves governed by ADRs in `decisions/`. Convention changes are non-trivial — they propagate to every Phase.
