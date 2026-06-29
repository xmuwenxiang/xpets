# Phase 2 — Round 1 (Spec Review Revision) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Phase 2 的 5 份 Work Spec + overview 从 `Draft` 推到 `Approved`，消解全部 TBD/placeholder，补全 4-category Acceptance，达到 `00-spec-conventions.md §10` 合规，作为第二轮实现的门禁。

**Architecture:** 评审轮的"测试"是一个可复用 spec-lint 脚本 `scripts/phase2-spec-lint.sh`，先红（TBD/placeholder/非 Approved 状态存在）后绿。lint 只扫 6 个规范文件（`overview.md` + `spec-001..005`），排除 `execution-plan.md` / `acceptance.md` / `checklist.md`（它们会合法描述 TBD）。评审轮按 `execution-plan.md §2.5` 单 commit 收尾。

**Tech Stack:** Bash lint + Markdown spec edits + GitHub Actions CI 接入。

**Scope:** 仅第一轮（评审修订）。第二轮（spec-001..005 TDD 实现）另出计划。本轮不写任何 Swift 代码。

---

## File Structure

| 文件 | 责任 | 本轮动作 |
|---|---|---|
| `scripts/phase2-spec-lint.sh` | Phase 2 spec 健康门禁（TBD/placeholder/Status/4-category/parity 文件） | 新建 |
| `specs/Phase-2-Rendering/spec-001-metal-renderer.md` | Metal Renderer backbone | 改 header + §5 TBD |
| `specs/Phase-2-Rendering/spec-002-material-pbr.md` | PBR Material | 改 header |
| `specs/Phase-2-Rendering/spec-003-lighting.md` | Lighting | 改 header |
| `specs/Phase-2-Rendering/spec-004-shadow.md` | Shadow | 改 header |
| `specs/Phase-2-Rendering/spec-005-hdr-post.md` | HDR Post | 改 header |
| `specs/Phase-2-Rendering/overview.md` | Phase 2 总览 | 改 Status + §Risk + §Acceptance |
| `specs/Phase-2-Rendering/acceptance.md` | 合并 4-category 验收表 | 新建 |
| `specs/Phase-2-Rendering/checklist.md` | 闭环 pre-flight | 新建 |
| `specs/README.md` | 顶层 spec 索引 | 改 §2 Phase-2 行 |
| `.github/workflows/ci.yml` | CI | 加 phase2-spec-lint 步骤 |

---

## Task 1: Author Phase-2 spec-lint script (red)

**Files:**
- Create: `scripts/phase2-spec-lint.sh`

- [ ] **Step 1: Write the lint script**

Create `scripts/phase2-spec-lint.sh`:

```bash
#!/usr/bin/env bash
# scripts/phase2-spec-lint.sh
#
# Phase 2 spec health gate. Mirrors 00-spec-conventions.md §10 (no TBD) and
# §7 (Approved = implementation gate). Also enforces acceptance.md +
# checklist.md parity with Phase 1 (§4.1/§4.2) and the D-013 4-category rule.
#
# Scope: only the 6 canonical spec files (overview + spec-001..005).
# execution-plan.md / acceptance.md / checklist.md may legitimately mention
# "TBD" descriptively and are excluded.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
PHASE="specs/Phase-2-Rendering"

# Canonical spec files only.
FILES=(
  "$PHASE/overview.md"
  "$PHASE/spec-001-metal-renderer.md"
  "$PHASE/spec-002-material-pbr.md"
  "$PHASE/spec-003-lighting.md"
  "$PHASE/spec-004-shadow.md"
  "$PHASE/spec-005-hdr-post.md"
)

fail=0

# 1. No TBD anywhere in canonical specs (§10).
if grep -rn 'TBD' "${FILES[@]}"; then
  echo "::error::TBD forbidden in canonical Phase-2 specs (00-spec-conventions.md §10)"
  fail=1
fi

# 2. No de-placeholder marker (resolved at review pass).
if grep -rn 'placeholder — to be expanded' "${FILES[@]}"; then
  echo "::error::placeholder marker still present in canonical Phase-2 specs"
  fail=1
fi

# 3. Each Work Spec carries a 'Status: Approved' header line (§7).
for spec in "$PHASE"/spec-*.md; do
  if ! grep -q '^Status: Approved$' "$spec"; then
    echo "::error::$spec missing 'Status: Approved' header line"
    fail=1
  fi
done

# 4. overview carries an Approved status value (must match the blockquote
#    status prefix `> **Status**: **Approved`, not the word "Approved"
#    appearing in prose — the §7 cross-ref mentions `Status: Approved`).
if ! grep -q '> \*\*Status\*\*: \*\*Approved' "$PHASE/overview.md"; then
  echo "::error::overview.md missing Approved status"
  fail=1
fi

# 5. acceptance.md + checklist.md present (§4.1/§4.2 parity with Phase 1).
for f in acceptance.md checklist.md; do
  if [[ ! -f "$PHASE/$f" ]]; then
    echo "::error::$PHASE/$f missing"
    fail=1
  fi
done

# 6. acceptance.md carries all 4 D-013 categories.
for cat in 'Performance' 'Enumerable' 'Assertable' 'Regression'; do
  if ! grep -q "$cat" "$PHASE/acceptance.md"; then
    echo "::error::acceptance.md missing D-013 category: $cat"
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "phase2-spec-lint: FAIL"
  exit 1
fi
echo "phase2-spec-lint: PASS"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/phase2-spec-lint.sh`

- [ ] **Step 3: Run lint to verify it fails (red)**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: FAIL — prints TBD hits (5× `Owner: TBD` + spec-001 §5 `(TBD ms per Pass)`), 2× placeholder marker (overview §Risk/§Acceptance), 5× missing `Status: Approved`, overview missing Approved, acceptance.md + checklist.md missing. `exit=1`.

> This is the red state. Do not commit yet — all subsequent tasks drive this lint to green.

---

## Task 2: Resolve spec-001 TBD threshold + header

**Files:**
- Modify: `specs/Phase-2-Rendering/spec-001-metal-renderer.md` (header lines 2 & 4; §5 line 71)

- [ ] **Step 1: Fix the §5 TBD threshold**

In `specs/Phase-2-Rendering/spec-001-metal-renderer.md`, replace:

```
- Per-Pass GPU-time percentile P99 over 600-frame window is logged via `Profiler`; CI asserts P99 ≤ (TBD ms per Pass) — placeholder threshold, finalized at Phase 2 kickoff.
```

with:

```
- Per-Pass GPU-time percentile P99 over 600-frame window is logged via `Profiler`; for the backbone no-op Pass (dispatch overhead only) CI asserts P99 ≤ 0.5 ms. Heavy passes (Material / Lighting / Shadow / HDR) carry their own per-spec P99 budgets and are exempt from this generic ceiling.
```

- [ ] **Step 2: Fix the header Status + Owner**

In the same file, replace the header block:

```
Status: Draft
Phase: 2 — Rendering
Owner: TBD
```

with:

```
Status: Approved
Phase: 2 — Rendering
Owner: Xavier Zhang
```

- [ ] **Step 3: Run lint — confirm 2 fewer failures**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: still FAIL overall, but spec-001 no longer appears in the TBD list and no longer appears in the missing-`Status: Approved` list. Other specs still fail. `exit=1`.

---

## Task 3: Update headers for spec-002..005 + overview status

**Files:**
- Modify: `specs/Phase-2-Rendering/spec-002-material-pbr.md` (header lines 2 & 4)
- Modify: `specs/Phase-2-Rendering/spec-003-lighting.md` (header lines 2 & 4)
- Modify: `specs/Phase-2-Rendering/spec-004-shadow.md` (header lines 2 & 4)
- Modify: `specs/Phase-2-Rendering/spec-005-hdr-post.md` (header lines 2 & 4)
- Modify: `specs/Phase-2-Rendering/overview.md` (line 3 status)

- [ ] **Step 1: spec-002 header**

In `spec-002-material-pbr.md`, replace:

```
Status: Draft
Phase: 2 — Rendering
Owner: TBD
```

with:

```
Status: Approved
Phase: 2 — Rendering
Owner: Xavier Zhang
```

- [ ] **Step 2: spec-003 header**

In `spec-003-lighting.md`, replace the same 3-line block (`Status: Draft` / `Phase: 2 — Rendering` / `Owner: TBD`) with the `Status: Approved` / `Phase: 2 — Rendering` / `Owner: Xavier Zhang` block.

- [ ] **Step 3: spec-004 header**

In `spec-004-shadow.md`, replace the same 3-line block with the Approved/Xavier Zhang block.

- [ ] **Step 4: spec-005 header**

In `spec-005-hdr-post.md`, replace the same 3-line block with the Approved/Xavier Zhang block.

- [ ] **Step 5: overview status line**

In `overview.md`, replace line 3:

```
> **Status**: Stub → **Drafts authored (2026-06-28)**. Five Work Specs now exist at Apple Style + 4-category Acceptance; none has entered `In Review`. Implementation does not begin until owner review + `Status: Approved` per `00-spec-conventions.md` §7.
```

with:

```
> **Status**: **Approved (2026-06-29)**. Five Work Specs at Apple Style + 4-category Acceptance, owner-reviewed. Implementation may begin per `00-spec-conventions.md` §7; execution plan in [`execution-plan.md`](execution-plan.md).
```

- [ ] **Step 6: Run lint — confirm header failures cleared**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: still FAIL overall (placeholder markers + missing acceptance.md/checklist.md remain), but **no** `missing 'Status: Approved'` lines and **no** overview-missing-Approved line, and **no** TBD lines (all Owner TBD + spec-001 §5 fixed). `exit=1`.

---

## Task 4: De-placeholderize overview §Risk

**Files:**
- Modify: `specs/Phase-2-Rendering/overview.md` (§Risk heading line 59 + body)

- [ ] **Step 1: Rewrite §Risk heading + keep body, firm up**

In `overview.md`, replace:

```
## Risk (placeholder — to be expanded)

- Metal Performance Shader compatibility on Apple Silicon
- IBL specular resolution vs frame budget
- Shadow acne with PBR materials
- Camera coordinate convention vs Phase 5 Desktop Space — addressed via the render-route decision documented in Phase 5a overview (D-005 lays out the 5a/5b split; the individual render-route sub-decision is left open until Phase 5a content authoring begins)
```

with:

```
## Risk

- **MPS compatibility on Apple Silicon** — Phase 2 ships hand-written Metal shaders; MPS is not on the critical path. If a later spec pulls in MPS, gate on `macos-14` runner only.
- **IBL specular resolution vs frame budget** — pre-filtered mip chain generated once at boot (async on a background `DispatchQueue`, synthetic-gradient fallback for the first frame); steady-state probe is cached, not rebuilt per frame (spec-003 §4).
- **Shadow acne on PBR low-roughness surfaces** — `biasMode = .slopeScaled` is the Phase-2 default; PBR shader reads bias from `ShadowConfig` (spec-004 §4).
- **Camera coordinate convention vs Phase 5 Desktop Space** — world-relative light direction stored as `SIMD3<Float>`; renderer recomputes view-projection on resize. The render-route sub-decision (offscreen-compositor vs direct-on-window) is owned by Phase 5a per D-005; Phase 2 only governs the renderer surface, not the route.
```

- [ ] **Step 2: Run lint — confirm one placeholder marker gone**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: still FAIL, but only **one** `placeholder — to be expanded` hit remains (the §Acceptance heading). `exit=1`.

---

## Task 5: Rewrite overview §Acceptance into 4-category form

**Files:**
- Modify: `specs/Phase-2-Rendering/overview.md` (§Acceptance heading line 68 + body)

- [ ] **Step 1: Replace the placeholder §Acceptance with 4-category content**

In `overview.md`, replace:

```
## Acceptance (placeholder — to be expanded using 4 categories)

- Fox self-renders with PBR realism
- HDR pipeline active with Tone Mapping
- Shadow cast onto ground plane
- Camera control stable across 60 s
```

with:

```
## Acceptance

> Distilled from the 5 Work Specs; full per-item table in [`acceptance.md`](acceptance.md). 4-category form per D-013.

### Performance metric

- `Renderer.tick(_:)` CPU ≤ 4 ms @ 60 FPS with 6 Passes registered (spec-001).
- no-op Pass GPU P99 ≤ 0.5 ms over 600-frame window (spec-001 backbone overhead); heavy passes carry per-spec P99 budgets (Lighting ≤ 1.5 ms, Shadow ≤ 2.5 ms, HDR ≤ 1.2 ms).
- Profiler `.everyFrame` overhead ≤ 0.5 ms / frame through Phase 2 (Phase-1 row 24 regression).
- Cumulative Phase-2 memory ≤ 128 MB worst-case (65 baseline + Renderer 15 + Material 6 + Lighting 6 + Shadow 24 + HDR 12).

### Enumerable use case

- Register 4 passes → order `[root, A, B, C, D]`; unregister `B` → `[root, A, C, D]` (spec-001).
- Material index `0` vs `1` → render differs at ≥ 5 % mean-L2 (spec-002).
- DirLight rotated 90° around Y → specular highlight follows (spec-003).
- 1 / 2 / 4 cascade × 512 / 2048 / 2048 → shadow coverage / sharpness / no `MTLTexture` reallocation in 60-frame run (spec-004).
- `toneMapper = .acesFilmic` vs `.none` → clipped bright-edge band; `exposure = 0.5` vs `1.0` ΔE ≥ 3 (spec-005).

### Assertable state

- `Renderer.currentFrameIndex == 0` at init, +1 per `tick`; `MTLDevice` in-process count == 1 (spec-001).
- `Material.fromGlb(i)` pure (== on repeat); `missingChannel` throws; texture cache `.hit` on second render (spec-002).
- `LightingState` `Sendable`; IBL probe cached `==`; `noLightsDuringIBLFallback` fires in strict mode only (spec-003).
- `MTLTexture.arrayLength == cascadeCount`; `invalidCascadeCount` throws at registration; `ContactShadowToggle.enable = true` zero side-effect (spec-004).
- `HDRConfig.toneMapper` `Codable` round-trip; `BloomPass.register()` does not mutate pass-order list; black scene → canvas max-Y == 0 (spec-005).

### Previous-Phase regression

- All Phase-1 `acceptance.md` rows 1..31 still pass — re-run `swift test` + CI green.
- Memory baseline ≤ 65 MB must not exceed 80 MB after spec-001 (≤ 15 MB Renderer ceiling); cumulative ≤ 128 MB at Phase-2 close.
```

- [ ] **Step 2: Run lint — confirm placeholder markers fully gone**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: still FAIL, but **zero** `placeholder — to be expanded` hits and **zero** TBD hits. Remaining failures: missing `acceptance.md` + `checklist.md`. `exit=1`.

---

## Task 6: Create acceptance.md (consolidated 4-category table)

**Files:**
- Create: `specs/Phase-2-Rendering/acceptance.md`

- [ ] **Step 1: Write the consolidated acceptance table**

Create `specs/Phase-2-Rendering/acceptance.md`:

````markdown
# Phase 2 — Acceptance (End-to-End)

> Every Phase-2 Acceptance criterion in one place, mapped to the owning Work Spec. Used during close-out review and E2E demo scripting. 4-category form per D-013 (`00-spec-conventions.md` §3.5).
>
> **Verifier convention**: `Unit test` / `Integration test` run in CI (`macos-14`); `Local visual baseline (M4)` runs via offline frame-capture on the owner machine, recorded into this file's evidence section — **not** gated in CI (reference frames are fragile).

---

## B.1 Renderer Backbone (spec-001)

| # | Item | Category | Verifier |
|---|---|---|---|
| 1 | `Renderer.tick(_:)` CPU ≤ 4 ms @ 60 FPS with 6 Passes | Performance | Integration test |
| 2 | no-op Pass GPU P99 ≤ 0.5 ms over 600-frame window | Performance | Local visual baseline (M4) |
| 3 | Register 4 → `[root,A,B,C,D]`; unregister `B` → `[root,A,C,D]` | Enumerable | Unit test |
| 4 | Duplicate Pass ID → `RendererError.duplicatePassID`, original preserved | Enumerable | Unit test |
| 5 | `currentFrameIndex == 0` at init; +1 per tick | Assertable | Unit test |
| 6 | `MTLDevice` in-process count == 1 | Assertable | Unit test |
| 7 | Register after first tick → `RendererError.alreadyRunning` | Assertable | Unit test |
| 8 | `unregisterPass` → `weakPass == nil` after drain | Assertable | Unit test |

## B.2 PBR Material (spec-002)

| # | Item | Category | Verifier |
|---|---|---|---|
| 9 | Material re-bind ≤ 0.3 ms / draw call (same SamplerState) | Performance | Integration test |
| 10 | `MaterialPass` memory delta ≤ 6 MB on Phase-1 baseline | Performance | Integration test |
| 11 | Material index 0 vs 1 → render differs ≥ 5 % mean-L2 | Enumerable | Local visual baseline (M4) |
| 12 | AO-only material darkens cavity ≥ 2 % mean-L2 vs baseline | Enumerable | Local visual baseline (M4) |
| 13 | `Material.fromGlb(i)` pure — repeat call returns `==` | Assertable | Unit test |
| 14 | Missing channel → `MaterialError.missingChannel`; never zero-default | Assertable | Unit test |
| 15 | Texture cache `.hit` on second render of same material | Assertable | Unit test |

## B.3 Lighting (spec-003)

| # | Item | Category | Verifier |
|---|---|---|---|
| 16 | Lighting pass GPU P99 ≤ 1.5 ms over 600-frame window | Performance | Local visual baseline (M4) |
| 17 | IBL single-probe upload ≤ 8 ms one-time at boot | Performance | Integration test |
| 18 | `LightingState` packing ≤ 50 µs / frame | Performance | Integration test |
| 19 | null-dir + synthetic-IBL → cubemap-only contribution, ΔE ≤ 4 | Enumerable | Local visual baseline (M4) |
| 20 | DirLight 90° Y-rotation → highlight follows | Enumerable | Local visual baseline (M4) |
| 21 | `LightingState` `Sendable`; lock-free across Renderer thread | Assertable | Unit test |
| 22 | IBL probe one-shot per AssetKey; repeat returns cached `==` | Assertable | Unit test |
| 23 | `noLightsDuringIBLFallback` fires in strict mode only | Assertable | Unit test |

## B.4 Shadow (spec-004)

| # | Item | Category | Verifier |
|---|---|---|---|
| 24 | `ShadowPass.encode` GPU P99 ≤ 2.5 ms (2 cascade × 2048) | Performance | Local visual baseline (M4) |
| 25 | Shadow texture steady-state delta ≤ 24 MB | Performance | Integration test |
| 26 | `ContactShadowToggle.enable=true` adds zero GPU time | Performance | Unit test |
| 27 | 1 cascade × 512 → coverage ≥ 30 %; 2 × 2048 → ΔE ≤ 3; 4 × 2048 → no realloc in 60 frames | Enumerable | Local visual baseline (M4) |
| 28 | `biasMode = .adaptive` → no acne across 5 randomized light dirs | Enumerable | Local visual baseline (M4) |
| 29 | `MTLTexture.arrayLength == cascadeCount` | Assertable | Unit test |
| 30 | `cascadeCount = 0` → `ShadowError.invalidCascadeCount` at registration | Assertable | Unit test |
| 31 | `ContactShadowToggle` setters `Sendable`; zero render mutation | Assertable | Unit test |

## B.5 HDR Post (spec-005)

| # | Item | Category | Verifier |
|---|---|---|---|
| 32 | `HDRPostPass` GPU P99 ≤ 1.2 ms (incl. FXAA) | Performance | Local visual baseline (M4) |
| 33 | HDR framebuffer steady-state ≤ 32 MB (incl. Retina 2×) | Performance | Integration test |
| 34 | `BloomPass.register()` adds zero GPU time | Performance | Unit test |
| 35 | `.acesFilmic` + DirLight 1.0 → max-channel ≤ 1.0, ΔE ≤ 4 | Enumerable | Local visual baseline (M4) |
| 36 | `exposure = 0.5` vs `1.0` → ΔE ≥ 3; full vs zero intensity → luminance ratio ≥ 10× | Enumerable | Local visual baseline (M4) |
| 37 | `toneMapper` `Codable` round-trip via `DPFoundation.Config` | Assertable | Unit test |
| 38 | `BloomPass.register()` does not mutate `Renderer` pass-order list | Assertable | Unit test |
| 39 | Black scene (DirLight=0, IBL=null) → canvas max-Y == 0 | Assertable | Unit test |

## B.6 Previous-Phase Regression

| # | Item | Category | Verifier |
|---|---|---|---|
| 40 | All Phase-1 `acceptance.md` rows 1..31 still pass | Regression | CI (`swift test`) |
| 41 | Memory baseline ≤ 65 MB must not exceed 80 MB after spec-001 | Regression | Integration test |
| 42 | Cumulative Phase-2 memory ≤ 128 MB worst-case at close | Regression | Integration test |
| 43 | Profiler `.everyFrame` overhead ≤ 0.5 ms (Phase-1 row 24) re-asserted | Regression | CI (`ProfilerTests`) |

---

## Evidence (local visual baselines)

> Filled during Round 2 implementation, per spec. Each entry: fixture, command, recorded value, pass/fail. Not CI-gated.
>
> Format: `| spec | item # | command | recorded | status |`
````

- [ ] **Step 2: Run lint — confirm acceptance.md present + 4 categories detected**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: still FAIL, but the `acceptance.md missing` and the 4-category checks now pass. Only `checklist.md missing` remains. `exit=1`.

---

## Task 7: Create checklist.md (close-out pre-flight)

**Files:**
- Create: `specs/Phase-2-Rendering/checklist.md`

- [ ] **Step 1: Write the close-out checklist**

Create `specs/Phase-2-Rendering/checklist.md`:

````markdown
# Phase 2 — Close-out Checklist

> Sprint close review. Every box must be checked before Phase 3 begins.
>
> **Closure state 2026-06-29 (Round 1 review)**: 5 Work Specs promoted to `Status: Approved`; TBD/placeholder cleared; `acceptance.md` + `checklist.md` created. Implementation (Round 2) pending — Code & Build boxes remain unchecked until each spec reaches `Done`.

---

## Spec & Review (Round 1 — complete)

- [x] All five Work Specs `Status: Approved` (owner-reviewed 2026-06-29)
- [x] No `TBD` / `placeholder — to be expanded` in canonical specs (`scripts/phase2-spec-lint.sh` PASS)
- [x] `overview.md` §Acceptance rewritten in 4-category form (D-013)
- [x] `acceptance.md` created (43-row 4-category table)
- [x] `checklist.md` created
- [x] `execution-plan.md` committed (`539343d`)

## Code & Build (Round 2 — per spec)

- [ ] `spec-001-metal-renderer.md` `Status: Done`; logic tests green
- [ ] `spec-002-material-pbr.md` `Status: Done`; logic tests green
- [ ] `spec-003-lighting.md` `Status: Done`; logic tests green
- [ ] `spec-004-shadow.md` `Status: Done`; logic tests green
- [ ] `spec-005-hdr-post.md` `Status: Done`; logic tests green
- [ ] `swift build` 0 warnings / 0 errors
- [ ] `swift test` passes (Phase 1 + Phase 2 logic tests)
- [ ] Local visual baselines recorded in `acceptance.md` Evidence section

## Performance Budget (Round 2 — at close)

- [ ] Cumulative Phase-2 memory ≤ 128 MB worst-case
- [ ] Profiler `.everyFrame` overhead ≤ 0.5 ms (Phase-1 row 24) not regressed
- [ ] Per-spec GPU P99 baselines recorded (no-op ≤ 0.5 ms; Lighting ≤ 1.5 ms; Shadow ≤ 2.5 ms; HDR ≤ 1.2 ms)

## Documentation (Round 2 — at close)

- [ ] `api/renderer-api.md` updated
- [ ] `api/material-api.md` updated
- [ ] `api/lighting-api.md` updated
- [ ] `api/shadow-api.md` updated
- [ ] `api/hdr-api.md` updated

## Acceptance Sign-Off (Round 2 — at close)

- [ ] All 43 `acceptance.md` rows pass
- [ ] Phase 3 owner confirms readiness
- [ ] Project owner (Xavier Zhang) signs off

## Release (Round 2 — at close)

- [ ] Closure commit pushed to `origin/main`
- [ ] CI green (incl. `phase2-spec-lint` step)
- [ ] Git tag `phase-2-rendering` (gated on owner sign-off)
````

- [ ] **Step 2: Run lint — confirm green**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: `phase2-spec-lint: PASS`, `exit=0`.

---

## Task 8: Wire CI + update specs/README + commit

**Files:**
- Modify: `.github/workflows/ci.yml` (add step after "Spec consistency check")
- Modify: `specs/README.md` (§2 Phase-2 row)

- [ ] **Step 1: Add the lint step to CI**

In `.github/workflows/ci.yml`, after the "Spec consistency check (DRY, drift-guard)" step block, insert a new step:

```yaml
      - name: Phase 2 spec lint (no TBD, Approved status, 4-category)
        run: |
          set -euo pipefail
          chmod +x scripts/phase2-spec-lint.sh
          ./scripts/phase2-spec-lint.sh
```

- [ ] **Step 2: Update specs/README.md §2 Phase-2 row**

In `specs/README.md`, replace the Phase 2 table row's Status + Closure Proof:

```
| 2 | Rendering | 5 Work Specs **Draft** (2026-06-28) | [`Phase-2-Rendering/overview.md`](Phase-2-Rendering/overview.md) | Apple-Style + 4-category Acceptance drafted for spec-001..spec-005. Implementation gated on owner review + `Status: Approved` per `00-spec-conventions.md` §7. Cumulative Phase-2 memory budget target ≤ 128 MB worst-case (frozen for Phase-3/4/5 regression baselines). |
```

with:

```
| 2 | Rendering | 5 Work Specs **Approved** (2026-06-29) | [`Phase-2-Rendering/overview.md`](Phase-2-Rendering/overview.md) | Apple-Style + 4-category Acceptance for spec-001..spec-005, owner-reviewed. TBD/placeholder cleared (`scripts/phase2-spec-lint.sh` CI-gated). Implementation may begin; execution plan in [`Phase-2-Rendering/execution-plan.md`](Phase-2-Rendering/execution-plan.md). Cumulative Phase-2 memory budget ≤ 128 MB worst-case (frozen for Phase-3/4/5 regression baselines). |
```

- [ ] **Step 3: Run lint one final time (green)**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: `phase2-spec-lint: PASS`, `exit=0`.

- [ ] **Step 4: Verify no Swift regression (lint round touched no Swift)**

Run: `swift build --package-path desktop-pet-core 2>&1 | tail -3`
Expected: `Build complete!` (0 warnings, 0 errors) — confirms the docs-only round did not break the build.

- [ ] **Step 5: Commit (single commit per execution-plan §2.5)**

```bash
git add scripts/phase2-spec-lint.sh \
        specs/Phase-2-Rendering/spec-001-metal-renderer.md \
        specs/Phase-2-Rendering/spec-002-material-pbr.md \
        specs/Phase-2-Rendering/spec-003-lighting.md \
        specs/Phase-2-Rendering/spec-004-shadow.md \
        specs/Phase-2-Rendering/spec-005-hdr-post.md \
        specs/Phase-2-Rendering/overview.md \
        specs/Phase-2-Rendering/acceptance.md \
        specs/Phase-2-Rendering/checklist.md \
        specs/README.md \
        .github/workflows/ci.yml
git commit -m "specs(phase-2): review pass — TBD resolve + 4-category acceptance + Approved

- Resolve spec-001 §5 TBD: no-op Pass P99 ≤ 0.5 ms; heavy passes exempt.
- Promote 5 Work Specs + overview Draft → Approved; Owner = Xavier Zhang.
- De-placeholderize overview §Risk; rewrite §Acceptance in 4-category (D-013).
- Add acceptance.md (43-row 4-category table) + checklist.md (Phase 1 parity).
- Add scripts/phase2-spec-lint.sh (TBD/placeholder/Status/4-category gate) + CI step.
- Update specs/README §2 Phase-2 row.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Verify the commit**

Run: `git log -1 --oneline && git status`
Expected: clean working tree, new commit on `main`.

---

## Self-Review (already run by plan author)

- **Spec coverage**: execution-plan §2.1 4 项硬伤（spec-001 TBD、overview Risk placeholder、overview Acceptance placeholder、Owner TBD）→ Task 2/4/5/3 覆盖。§2.2 状态流转 → Task 2/3。§2.3 新文件 → Task 6/7。§2.4 一致性复核 → Task 8 CI + lint。§2.5 单 commit → Task 8 Step 5。无遗漏。
- **Placeholder scan**: 计划内无 TBD/TODO/"implement later"；所有编辑步骤含完整 old/new 串；lint 脚本与 acceptance.md/checklist.md 为完整内容。
- **Type consistency**: lint 中 `^Status: Approved$` 与 spec header 行精确匹配；overview 用 `Status.*Approved` 宽匹配（适配 blockquote 格式）；acceptance.md 4 category 名 `Performance/Enumerable/Assertable/Regression` 与 lint 第 6 项及 Phase-1 acceptance.md 一致。
