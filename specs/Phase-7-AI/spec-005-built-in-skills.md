<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: spec-004-skill-runtime.md, Phase 5 spec-004-desktop-world.md
-->

# SPEC-005 — Built-in Skills (Move / Jump / Sleep / Sit / PlayAnimation / LookAt / OpenApp / Speak)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> The eight built-in Skills the Pet ships with. Each Maps to one Intent case from `spec-003`.

---

## 1. Goal

Ship eight Skills out-of-the-box so Claude (or local Behavior) can do meaningful work at first launch. After SPEC-005 ships, every named skill is registered in the runtime with the requested permission set, version-pinned.

---

## 2. Deliverables

Eight Skills, each as a `Skill` protocol conformer:

| Skill | Required Permissions | Wire Path |
|---|---|---|
| `MoveSkill` | `.move` | Phase-3 Character Controller jump/walk + Phase-5 AnimationDriver.apply |
| `JumpSkill` | `.move` | Same as Move with vertical impulse |
| `SleepSkill` | (none) | Phase-4 BlendTree → Sleep clip |
| `SitSkill` | (none) | BlendTree → Sit clip |
| `PlayAnimationSkill(name)` | `.playAnimation` | Phase-4 BlendTree |
| `LookAtSkill(target)` | `.lookAt` | Phase-4 LookAtIK target (via Phase-5 foot-IK target source style) |
| `OpenAppSkill(bundleID)` | `.openApp` | macOS `NSWorkspace.launchApplication` |
| `SpeakSkill(text)` | `.speak` | TTS subsystem (Phase-9 polish; Phase-7 ships minimal stub) |

Each Skill ships with:
- Type-safe `SkillArguments` (Codable).
- Type-safe `SkillResult` (Codable).
- A unit test fixture and an integration test (where applicable).
- `version: "1.0.0"` static string.

Tests:
- Unit: each Skill registered → registry lookup by `name + version` returns the Skill.
- Unit: each Skill with missing required permissions throws.
- Integration: a MoveSkill invocation moves the fox's simulation by exactly the target distance within 60 frames.
- Integration: SpeakSkill with permission granted emits an audio output (asserted via test sink).
- `version` field tests for each skill.
- **API docs**: `api/built-in-skills-api.md` — Skill list, permissions matrix, version-pin policy.

---

## 3. Out of Scope

- ❌ Custom Skills (third-party) — Phase 9 Marketplace.
- ❌ SpeakSkill audio polish — Phase 9.
- ❌ OpenApp with `osascript` semantics — default-denied; Phase-7 ships via `NSWorkspace.launchApplication` only.

---

## 4. Risk

- **MoveSkill speed mismatch** — Mitigation: speed is configurable per-invocation; tests assert default 1.0 m/s.
- **SpeakSkill audio budget** — Mitigation: Phase-7 stub returns a typed `SpeakSkillResult` without actually emitting audio; Phase-9 wires TTS.
- **OpenApp macOS sandbox denial** — Mitigation: Skill.invoke throws `SkillError.openAppDenied` if macOS rejects; tested explicitly.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Each Skill invocation overhead ≤ 0.5 ms P99.
- MoveSkill end-to-end (intent → Bone mutation) ≤ 16 ms wall-clock.
- Memory delta ≤ 2 MB on top of `spec-004-skill-runtime.md`.

### Enumerable use case

- All 8 Skills register → registry count = 8.
- MoveSkill moves the fox by exactly the target distance within 60 frames.
- SpeakSkill (Phase-7 stub) emits SkillResult without crashing audio.
- version-pin: each Skill has `version == "1.0.0"` constant.

### Assertable state

- All 8 Skills registered with type-correct `requiredPermissions`.
- `version` strings are immutable at registry query time.
- Skills are `Sendable`; cross-thread invocation is safe.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
- Phase-5 AnimationDriver + Phase-4 IK solvers unchanged.
