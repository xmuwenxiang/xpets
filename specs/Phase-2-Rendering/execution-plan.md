# Phase 2 — 评审与实现执行计划

> **Status**: Active execution plan for Phase 2 (Rendering).
> **Owner**: Xavier Zhang (Project owner + Phase-2 owner per `Phase-1-Foundation/findings.md` §2).
> **Authored**: 2026-06-29.
> **Related**: [`overview.md`](overview.md) · [`00-spec-conventions.md`](../00-spec-conventions.md) · [`roadmap.md`](../../roadmap.md) §2 (Phase 2).
> **Decisions locked at kickoff**:
> - 推进路径 = 先评审修订再实现（评审与实现分离，可追溯）。
> - 实现切片 = 逐 spec 增量交付（spec-001 → 005），每个 spec 一个 TDD 循环。
> - 验收落地 = 逻辑/状态断言进 CI；视觉 ΔE + GPU-time P99 用本地 M4 离线抓帧脚本跑，基线记入 `acceptance.md` 证据区，CI 不强求。

---

## 1. Purpose

Phase 2 的 5 份 Work Spec 当前处于 `Status: Draft`，存在若干 TBD / placeholder，违反 `00-spec-conventions.md §10`（禁止 TBD）。本计划定义两轮工作：

- **第一轮 — Spec 评审修订**：消解所有 TBD/placeholder，补全 4-category Acceptance，状态推进到 `Approved`，提交。
- **第二轮 — 实现**：按 spec-001 → 005 依赖序，逐 spec 走 TDD 循环（红 → 实现 → 绿 → 提交）。

实现**不在评审轮闭合前开始**（`00-spec-conventions.md §7`：`Approved` 是实现门禁）。

---

## 2. 第一轮 — Spec 评审修订

### 2.1 硬伤消解（§10 合规）

| 位置 | 现状 | 修订 |
|---|---|---|
| `spec-001` §5 Performance | `P99 ≤ (TBD ms per Pass)` | 定为 **≤ 0.5 ms / no-op Pass（backbone 调度开销）**；重 Pass（Material/Lighting/Shadow/HDR）走各自 spec 的 P99 预算，豁免此通用上限。 |
| `overview.md` §Risk | "placeholder — to be expanded" | 4 条已具实质内容；去 placeholder 标签，补跨 Phase 风险（相机坐标约定 → Phase 5a render-route 子决策）。 |
| `overview.md` §Acceptance | "placeholder — to be expanded using 4 categories" | 重写为完整 **4-category**（D-013）形式，从 5 份 Work Spec Acceptance 蒸馏。 |
| 5 份 spec + overview `Owner: TBD` | TBD | 填 **Xavier Zhang**。 |

### 2.2 状态流转

5 份 Work Spec + overview：`Draft → In Review → Approved`。
Owner 即本轮评审签字人，`In Review` 为瞬时状态；修订完成即 `Approved`。

### 2.3 新增文件（与 Phase 1 对齐，§4.1/4.2 optional 但 Phase 1 既有）

- `Phase-2-Rendering/acceptance.md` — 合并 4-category 验收表（Performance / Enumerable / Assertable / Previous-Phase regression），作为闭环证据载体。
- `Phase-2-Rendering/checklist.md` — 闭环 pre-flight（CI 绿、docs 更新、内存预算 ≤ 128 MB、Phase 1 回归基线、Profiler ≤ 0.5 ms 行不回归）。

### 2.4 一致性校验（不阻塞评审）

- Future-Spec 残桩（`ContactShadowToggle` / `BloomPass`）：近 3 次提交（`1980490` / `7109216`）已修正，仅复核 no-op 语义与 overview §Future-Spec 一致。
- `api/*` 文档（`renderer-api.md` / `material-api.md` / `lighting-api.md` / `shadow-api.md` / `hdr-api.md`）：列为实现期交付物，评审轮不创建。

### 2.5 提交

评审修订作为一个 commit：
```
specs(phase-2): review pass — TBD resolve + 4-category acceptance + Approved
```

---

## 3. 第二轮 — 实现（逐 spec TDD）

### 3.1 依赖序

线性实现序（满足各 spec `Depends` 头声明的全部依赖）：

```
spec-001 → spec-002 → spec-003 → spec-004 → spec-005
```

声明依赖（来自各 spec 头）：002←001；003←001,002；004←001,002,003；005←001,003。
线性序保证任一 spec 启动时其依赖均已 `Done`。无并行；可在任一 spec 闭环后暂停审查。

### 3.2 每 spec 的 TDD 循环

1. **红**：先写该 spec 的逻辑/状态断言测试（CI 可跑、无 GPU 依赖），确认失败。
2. **实现**：写源码使逻辑测试转绿。
3. **视觉/基线**：本地 M4 跑离线抓帧脚本，记录 ΔE / GPU P99 基线到 `acceptance.md` 证据区。
4. **提交**：`impl(phase-2/spec-NNN): <slug>`。

### 3.3 交付与验收矩阵

| spec | 核心交付 | CI 逻辑测试（示例） | 本地视觉基线 |
|---|---|---|---|
| 001 Metal Renderer | `RenderPass` 协议、`register/unregisterPass`、`currentFrameIndex`、Profiler Counter | 顺序 `[root,A,B,C,D]`；unregister 后 `[A,C]`；`alreadyRunning`；`duplicatePassID`；`gpuCount==1`；`weakPass==nil` | no-op Pass P99 ≤ 0.5 ms |
| 002 PBR Material | `Material` 值类型、`MaterialPass`、texture-hash cache、`fromGlb` | `fromGlb` 纯等值；`missingChannel` 抛错；cache `.hit`；`gpuLabel=="pbr.material"` | PBR vs Phase-1 mono-tone ΔE ≥ 5 % |
| 003 Lighting | `LightingState`、`LightingPass`、`IBLProbe`、合成渐变 fallback | `Sendable`；probe 缓存等值；`noLightsDuringIBLFallback` 仅 strict；`weakMTLTexture==nil` | cubemap-only vs null ΔE ≥ 5 % |
| 004 Shadow | `ShadowConfig`、`ShadowPass`、PCF、`ContactShadowToggle` no-op | `arrayLength==cascadeCount`；`invalidCascadeCount` 抛错；ContactShadow 零副作用；weak release | 45° 光照阴影 ΔE ≤ 4 |
| 005 HDR Post | `HDRConfig`、`HDRPostPass`、FXAA、`BloomPass` no-op | `toneMapper` Codable；`BloomPass` 不动 registry；黑场景 max-Y==0；`.none` clip | full vs zero intensity ΔE > 50 |

### 3.4 内存预算（frozen 回归基线）

Phase 1 ≤ 65 MB → Phase 2 worst-case ≤ 128 MB（Renderer 15 + Material 6 + Lighting 6 + Shadow 24 + HDR 12 + 基线 65 ≈ 128）。每 spec 闭环时在 `acceptance.md` 记累积值，超限则 raise `findings.md` ADR。

---

## 4. 技术注记

- **Metal 3 vs Metal 4**：本机 M4 / Metal 4；spec 写 "macOS 14 / Metal 3"。Metal 3 API 在 M4 完全可用，实现沿用 Metal 3 API 保 spec 保真度；若 Metal 4 有显著更优解，单独提 ADR 再切，不阻塞。
- **fox.glb fixture**：`Tests/DPAssetTests/Fixtures/fox.glb` 已存在（Phase 1 冻结哈希），spec-002 `Material.fromGlb` 直接消费。
- **CI runner**：`macos-14`（Apple Silicon），逻辑测试可跑；视觉 ΔE / GPU P99 不入 CI（参考帧易碎），仅本地基线。

---

## 5. 出口标准（第二轮每 spec 闭环）

- 该 spec `Status: Implementing → Done`。
- CI 逻辑测试绿，Phase 1 全部回归行仍绿。
- 本地视觉基线记入 `acceptance.md`。
- 内存累积值未超 §3.4 预算。

Phase 2 整体闭环：5 份 spec 全 `Done` + `checklist.md` 全勾 + `acceptance.md` 全绿 + git tag `phase-2-rendering`（owner 签字后）。

---

## 6. 下一动作

本计划经用户复核后，进入 `superpowers:writing-plans` 出第一轮（评审修订）的逐步实现计划。
