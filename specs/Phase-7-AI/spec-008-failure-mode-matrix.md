<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: spec-001-claude-runtime.md, spec-002-claude-ipc.md, spec-003-intent-executor.md
-->

# SPEC-008 — Failure Mode Matrix (Mandatory, D-007-style)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **Mandatory sub-Spec for Phase 7.** Lists the failure modes the Runtime must handle gracefully and the degradation strategy per mode. Each row has an executable test fixture, not just prose.

---

## 1. Goal

Ensure the Pet is alive even when Claude is unhealthy. After SPEC-008 ships, every known Claude failure mode degrades to a typed local fallback; the user is informed via animation + optional toast; the Runtime continues ticking without dropping presence.

---

## 2. Deliverables

- **Failure Mode Matrix table** (≥ 5 rows; default 5 listed in Phase-7 overview):

| ID | Scenario | Detection | Pet Strategy | Test Fixture ID |
|---|---|---|---|---|
| `FM-1` | Network offline | `NWPath.status == .unsatisfied` for ≥ 5 s | Fallback to local Behavior; animate Idle-Sad | `testFM1_networkOffline_fallsBackLocal` |
| `FM-2` | Token exhausted (429) | IPC reply code `429` | Fallback + non-blocking toast: "Token limit reached. Pausing chat." | `testFM2_tokenExhausted_toastLogged` |
| `FM-3` | Anthropic 5xx (500/502/503) | IPC reply code in {500,502,503} | Exponential backoff (1, 2, 4, 8, 16 s capped) × 5 retries; fallback after | `testFM3_5xx_exponentialBackoff` |
| `FM-4` | Tool Permission Denied | Skill throws `permissionDenied` | Skill aborts gracefully; Pet animates Confused state; recovery after 1 s | `testFM4_toolPermDenied_confusedAnimation` |
| `FM-5` | Intent parse failure (JSON malformed) | `IntentExecutor.execute` returns `.parseError` | Local retry × 3; fallback to local-mode after | `testFM5_intentParseFailure_threeRetries` |

- `FailureModeRegistry`: typed store of `(id, scenario, strategy)` rows; CI test asserts all rows have a test fixture ID.
- Recovery state machine per mode:
  - `attempt → backoff/timeout → fallback → resume`.
  - The Pet never crashes due to a Claude failure; tests assert Runtime stability through all 5 modes.
- Telemetry: each fallback emits a `TelemetryEvent.fallbackUsed(mode:)` (also consumed by Phase-9 Telemetry).
- Tests:
  - Unit: each FM-1..FM-5 row has a unit test fixture.
  - Integration: 5 fallback paths in a single 60-frame soak — no crash, no spin.
  - Assertable: `FailureModeRegistry` exposes a static table; boot doesn't require runtime initialization.
- **API docs**: `api/failure-mode-matrix-api.md` — table, registry, telemetry hooks.

---

## 3. Out of Scope

- ❌ Recovery beyond 5 listed modes (e.g. Anthropic policy violations, OAuth revocation) — Phase-9 may extend.
- ❌ Self-healing repair of Claude — out.
- ❌ Telemetry persistence — Phase 9.

---

## 4. Risk

- **Local fallback also failing** — Mitigation: local Behavior is local-only (Phase 6); if Phase-6 Behavior itself throws, Runtime catches and surfaces a Bird-on-the-Wire visible error in 5 s, no infinite loop.
- **Test fixtures drift** — Mitigation: each FM row carries a fixture ID and a CI assertion scanning source for `testFM1_*` etc.
- **Backoff timer accuracy** at long delays — Mitigation: backoff uses `DispatchQueue.asyncAfter`; tolerances absorbed by the +1 s cap.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Fallback transition latency ≤ 6 frames (≤ 100 ms) for FM-1..FM-5.
- Memory delta ≤ 0.5 MB on top of `spec-007-chat-panel.md`.
- Profiler budget unchanged.

### Enumerable use case

- FM-1 → offline; Runtime detects, pet animates Idle-Sad; no chat panel update.
- FM-2 → 429; toast emitted, fallback engaged.
- FM-3 → 5xx; backoff schedule observed (1, 2, 4, 8, 16 s); fallback after 5 retries.
- FM-4 → permission denied; confused animation; recovery after 1 s.
- FM-5 → 3 retries, then fallback.

### Assertable state

- `FailureModeRegistry` has exactly 5 default rows at boot.
- Each row carries a unique `id` (`FM-1..FM-5`).
- `TelemetryEvent.fallbackUsed(mode:)` is emitted exactly once per fallback engagement.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
- Runtime.tick semantics unchanged.
- Profiler `.everyFrame` ≤ 0.5 ms.
