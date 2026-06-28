<!--
Status: Draft
Phase: 6 — Behavior
-->



# SPEC-004 — Memory (Local SQLite-Backed Store)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Memory persists across runtime instances. SQLite-backed in Phase 6 (not deferred).

---

## 1. Goal

Provide a typed memory store with three tiers: short-term (last 5 minutes), mid-term (today), long-term (all-time). Persistence is local-only; no network, no cloud.

After SPEC-004 ships, the Pet recalls the user's morning greeting, the recent conversation, and the user's preferred Idle; all are observable and timestamped.

---

## 2. Deliverables

- `DPBehavior.MemoryStore`:
  - SQLite database stored at `Application Support/PetMemory.sqlite`.
  - WAL mode (single writer, multi-reader).
  - Tables: `ShortTermMemory`, `MidTermMemory`, `LongTermMemory`.
  - Schema: `(id, kind, payload_json, created_at, last_accessed_at, access_count)`.
- `MemoryRecord` value type:
  - `kind: String`, `payload: [String: AnyCodable]`, timestamps, access counts.
  - `Sendable` and `Codable`.
- Tier-specific retention:
  - ShortTerm: ≤ 5 min, eviction at 5 min mark, automatic.
  - MidTerm: ≤ 24 h, eviction at midnight.
  - LongTerm: persistent, manual prune.
- Search:
  - `query(kind:)`, `query(textLike:)`, `query(recent:)`.
  - FTS5 index on payload for `textLike`.
- Privacy: stored memory MUST respect Phase-6 Privacy Spec — never capture `.sensitive` content; tests assert.
- Tests:
  - Unit: insert 100 records, evict short-term after 5 min → count ≤ 50.
  - Unit: insert, search by `kind` → returns matching records.
  - Unit: insert, FTS search by text → returns matching records, ≤ 1 ms.
  - Privacy: attempt to insert a `.sensitive` payload → rejected with `MemoryError.sensitiveRejected`.

---

## 3. Out of Scope

- ❌ Cloud / iCloud sync — out.
- ❌ Machine-learning embeddings on memory — out.

---

## 4. Risk

- **SQLite write contention** — Mitigation: WAL mode; serial writes; tests assert ≤ 100 µs for typical writes.
- **Schema migration drift** — Mitigation: `version` column; migrations tested.
- **Privacy leaks via Snapshot at app launch** — Mitigation: Snapshot serializer rejects `.sensitive` rows.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Insert ≤ 100 µs P99.
- FTS5 `textLike` ≤ 1 ms P99 over 10 K records.
- Memory delta ≤ 2 MB on top of `spec-002`.

### Enumerable

- Insert 100 records → evict 50 → count = 50.
- FTS search → returns matches.
- Sensitive payload → rejected.

### Assertable

- WAL mode enabled at boot.
- `MemoryError.sensitiveRejected` is statically defined.

### Regression

- Phase 1..5 Acceptance still pass; Profiler budget unchanged.
