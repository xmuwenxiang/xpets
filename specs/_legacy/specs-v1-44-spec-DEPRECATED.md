# ⚠️ DEPRECATED — Superseded by Phase-Based Specs (v2)

> **Status**: HISTORICAL — DO NOT IMPLEMENT FROM THIS DOCUMENT.
> **Superseded by**: `specs/` Phase 1~9 v2 (created 2026-06-28).
> **Reason for deprecation**: 15-Phase / 44-Spec module-based decomposition caused cross-phase dependency jumps during development (Renderer → Scene → Physics → Resource → AI). Replaced with 10-Phase milestone-based decomposition aligned with Apple/Google/Godot/Unity conventions.
> **Migration map**: see `specs/_legacy/migration-map.md` (companion file).
>
> The content below is preserved verbatim for traceability only.

---

这是我建议的开发方式。

不要直接开始编码，而是先完成一套完整的 Specs。

对于这种偏 Runtime + Engine 的项目，我建议采用类似 Apple、Linear、Anthropic 的工程管理方式，将系统拆解为一系列独立的 Specification，每个 Spec 都能独立开发、测试和验收。

下面这份文档就是整个项目的开发蓝图。

⸻

AI Native 3D Desktop Pet

Development Specifications（Specs）

Version: 1.0

⸻

开发原则

整个项目按照模块化 Specs 开发。

每一个 Spec 都具有：

* 独立职责
* 独立接口
* 独立测试
* 独立验收

所有 Spec 完成后组成最终 Runtime。

⸻

Overall Roadmap

Desktop Pet
├── Foundation
├── Rendering
├── Physics
├── Animation
├── Scene
├── Navigation
├── Behavior
├── Runtime
├── AI
├── Skills
├── UI
├── Assets
└── Release

预计约 20 个 Specs。

⸻

Phase 1：Foundation

⸻

SPEC-001 Project Bootstrap

目标

建立整个工程。

内容

* Swift Package
* Xcode Project
* Module Layout
* Build Script
* Logger
* Config

输出

DesktopPet.app

⸻

SPEC-002 Window System

目标

实现桌面 Overlay。

功能

透明窗口

AlwaysOnTop

Click Through

Desktop Layer

多显示器支持

验收

模型可以悬浮在桌面。

⸻

SPEC-003 Runtime Architecture

目标

建立 Runtime 生命周期。

包括：

Application

Scene

Update Loop

Shutdown

Module Manager

⸻

Phase 2：Rendering Engine

⸻

SPEC-004 Metal Renderer

目标

实现 Renderer。

包括：

Renderer

RenderPass

Camera

Scene

GPU Command

Frame Loop

验收

可以绘制 Mesh。

⸻

SPEC-005 Resource Manager

负责

GLB

Texture

Shader

Material

Animation

缓存管理。

支持：

异步加载。

⸻

SPEC-006 Material System

实现：

PBR

Metallic

Roughness

Normal

AO

Environment

HDR

⸻

SPEC-007 Lighting

支持：

Directional Light

Point Light

Environment Map

IBL

Shadow

⸻

SPEC-008 Post Processing

支持：

Bloom

SSAO

Tone Mapping

FXAA

Motion Blur（预留）

⸻

Phase 3：Physics

⸻

SPEC-009 Physics Engine

集成：

Jolt Physics

负责：

World

RigidBody

Constraint

Collision

Gravity

⸻

SPEC-010 Character Physics

负责：

狐狸移动。

支持：

Walk

Jump

Landing

Slope

Obstacle

⸻

SPEC-011 Secondary Motion

负责：

尾巴

耳朵

项圈

支持：

Spring

Inertia

Damping

⸻

Phase 4：Animation

⸻

SPEC-012 Skeleton Runtime

支持：

Skeleton

Bone

Pose

GPU Skinning

⸻

SPEC-013 Animation System

支持：

Idle

Walk

Run

Jump

Sleep

Eat

Scratch

Observe

⸻

SPEC-014 Blend Tree

支持：

Animation Blend

Cross Fade

Random Idle

Animation Layer

⸻

SPEC-015 IK System

支持：

Head LookAt

Eye LookAt

Foot IK

Ground Alignment

⸻

Phase 5：Scene

⸻

SPEC-016 Scene Graph

支持：

Scene

Node

Transform

Parent Child

⸻

SPEC-017 Camera

支持：

Perspective

Orthographic

Follow

Shake

Debug

⸻

SPEC-018 Coordinate System

建立：

Desktop Space

↓

3D Space

实现：

桌面坐标

转换

世界坐标。

⸻

Phase 6：Navigation

⸻

SPEC-019 Desktop Mapping

建立：

Desktop World。

识别：

屏幕

Dock

Widget

Desktop Icon

Finder

窗口

⸻

SPEC-020 NavMesh

负责：

路径规划。

支持：

避障。

动态更新。

⸻

SPEC-021 Movement Controller

负责：

Walk

Run

Rotate

Jump

Follow

Target

⸻

Phase 7：Behavior

⸻

SPEC-022 FSM

实现：

状态机。

状态：

Idle

Walk

Sleep

Play

Eat

Talk

Observe

⸻

SPEC-023 Utility AI

负责：

行为评分。

例如：

Sleep Score

Play Score

Eat Score

Talk Score

Explore Score

选择：

最高优先级行为。

⸻

SPEC-024 Emotion

支持：

Mood

Energy

Curiosity

Trust

Happiness

影响：

行为选择。

⸻

Phase 8：AI Runtime

⸻

SPEC-025 Claude Runtime

负责：

Claude CLI

生命周期。

包括：

启动

停止

通信

超时

恢复

⸻

SPEC-026 IPC

支持：

Unix Socket

Streaming

JSON RPC

Tool Call

⸻

SPEC-027 Intent Executor

负责：

Claude Intent

转换

Runtime Action。

例如：

Sleep

↓

Walk
Sit
Sleep

⸻

Phase 9：Skill System

⸻

SPEC-028 Skill Runtime

支持：

Skill

Registry

Permission

Version

Lifecycle

⸻

SPEC-029 Built-in Skills

实现：

Move()

Jump()

Sleep()

Sit()

PlayAnimation()

LookAt()

OpenApp()

Speak()

⸻

SPEC-030 MCP Bridge

支持：

Claude Tool Call

↓

Skill

↓

Runtime。

⸻

Phase 10：Asset System

⸻

SPEC-031 Asset Pipeline

支持：

GLB

KTX2

Texture

Animation

Compression

⸻

SPEC-032 Asset Cache

负责：

Memory Cache

Disk Cache

Lazy Loading

⸻

Phase 11：Desktop World

⸻

SPEC-033 Desktop Object Detection

建立：

虚拟世界。

对象：

Dock

Finder

Widget

Desktop

Window

MenuBar

⸻

SPEC-034 World Event

监听：

窗口变化

鼠标

键盘

应用切换

屏幕变化

⸻

Phase 12：UI

⸻

SPEC-035 Settings

设置：

模型

AI

性能

主题

快捷键

⸻

SPEC-036 Chat Panel

聊天窗口。

支持：

Streaming

Markdown

Code

Image

⸻

SPEC-037 Debug Panel

显示：

FPS

Memory

Physics

NavMesh

Skeleton

Bounding Box

⸻

Phase 13：Persistence

⸻

SPEC-038 SQLite

保存：

Memory

Mood

History

Config

Conversation

⸻

SPEC-039 Save System

自动保存。

恢复。

迁移。

⸻

Phase 14：Performance

⸻

SPEC-040 Optimizer

负责：

CPU

GPU

Memory

Battery

优化。

⸻

SPEC-041 Frame Scheduler

支持：

60 FPS

30 FPS

Idle Mode

Sleep Mode

⸻

Phase 15：Release

⸻

SPEC-042 Auto Update

支持：

版本升级。

资源更新。

⸻

SPEC-043 Crash Report

异常恢复。

日志上传。

⸻

SPEC-044 Telemetry

统计：

FPS

Memory

Crash

Skill Usage

AI Usage

⸻

Milestone

M1

桌面透明窗口

GLB 模型加载

基础动画

⸻

M2

Physics

PBR

Shadow

行为系统

⸻

M3

Claude CLI

Skill

Memory

聊天

⸻

M4

桌面世界

NavMesh

完整 AI Runtime

⸻

M5

Beta Release

性能优化

资源压缩

Installer

⸻

开发顺序（推荐）

001 Bootstrap
↓
002 Window
↓
004 Renderer
↓
005 Resource
↓
012 Skeleton
↓
013 Animation
↓
009 Physics
↓
016 Scene
↓
019 Desktop Mapping
↓
020 NavMesh
↓
022 FSM
↓
023 Utility AI
↓
025 Claude Runtime
↓
028 Skill Runtime
↓
035 UI
↓
040 Optimizer
↓
Release

最终目标

整个项目最终形成三个相互解耦的核心子系统：

AI Layer
Claude CLI
──────────────
Runtime Layer
Behavior
Physics
Animation
Navigation
──────────────
Engine Layer
Metal
Renderer
Scene
Window
Assets

这种分层保证：

* Engine 可以脱离 AI 独立运行。
* AI 可以替换（Claude、OpenAI、本地模型等）。
* Runtime 可以扩展新的宠物、Skill 和行为，而无需修改底层渲染引擎。

整个系统将保持高内聚、低耦合，并适合长期演进为一个可扩展的 AI Native 桌面平台，而不仅仅是一款桌宠。