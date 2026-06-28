下面是我建议的第一版设计文档（Architecture Specification V1）。它不是单纯讨论技术选型，而是按照一个真正可开发的产品规格（Specification）来组织，后续可以继续细化成每个模块的详细设计、API 规范和开发任务。

⸻

AI Native 3D Desktop Pet

System Architecture Specification（v1.0）

Author: Xavier Zhang
Version: 1.0
Target Platform: macOS (Apple Silicon)
Status: Draft

⸻

1. 项目目标

1.1 项目定位

构建一款 AI 驱动的 3D 桌面宠物（AI Native Desktop Pet）。

区别于传统桌宠，本项目将 AI 与 3D Runtime 解耦：

* Claude CLI 负责思考
* Runtime 负责行为执行
* GPU 负责渲染
* Physics 负责物理模拟

最终打造一个真正”生活在桌面”的 AI 助手。

⸻

1.2 产品目标

产品应满足以下目标：

* 极轻量
* 极低资源占用
* 原生 macOS 体验
* 长时间后台运行
* 可扩展 Skill 系统
* AI Native

不是游戏。

而是一款系统级桌面应用。

⸻

2. 核心设计原则

Principle 1

AI 与 Runtime 解耦。

Claude CLI
↓
Intent
↓
Desktop Runtime

AI 不直接控制模型。

AI 仅表达：

我要去睡觉

Runtime 决定：

* 怎么走
* 怎么播放动画
* 怎么避障
* 怎么落地

⸻

Principle 2

不使用大型游戏引擎。

Reject：

* Unity
* Unreal
* Electron

Reason：

安装包大

内存高

大量无关功能

维护复杂

⸻

Principle 3

桌宠不是游戏。

采用 Disney Physics。

追求：

看起来真实。

而不是：

物理绝对真实。

⸻

3. 整体架构

                 Claude CLI
                      │
                Intent / Plan
                      │
──────────────────────────────────
           Desktop Runtime
──────────────────────────────────
Behavior System
↓
Navigation
↓
Physics
↓
Animation
↓
Rendering
↓
Desktop Overlay

⸻

4. Runtime 架构

DesktopPet.app
├── Overlay
├── Renderer
├── Physics
├── Animation
├── Behavior
├── Navigation
├── Skills
├── Memory
└── IPC

每个模块独立。

方便维护。

⸻

5. 技术栈

UI

SwiftUI

负责：

* 设置界面
* 配置页面
* 对话窗口

⸻

Window

AppKit

NSWindow

支持：

* Transparent
* AlwaysOnTop
* ClickThrough

实现桌面 Overlay。

⸻

Rendering

MetalKit

MTKView

完全 GPU 渲染。

支持：

* GPU Skinning
* Instancing
* Compute Shader

⸻

Resource

推荐：

glTF 2.0

GLB

KTX2 Texture

支持：

* Draco Compression

⸻

Animation

自研 Animation Runtime。

支持：

* Skeleton
* Blend Tree
* Animation State Machine
* IK

⸻

Physics

采用轻量级物理引擎。

推荐：

Jolt Physics

支持：

* Gravity
* Collision
* Rigidbody
* Spring
* Constraint

不实现：

* 流体
* 布料
* 大规模刚体

⸻

Navigation

桌面 NavMesh。

支持：

* 桌面边界
* Widget
* Dock
* 图标避障

⸻

Behavior

Utility AI

FSM

负责：

行为评分

例如：

Sleep

Eat

Play

Observe

Talk

Explore

⸻

AI

Claude CLI

负责：

Reason

Memory

Plan

Tool Calling

不负责：

动画

移动

物理

⸻

Storage

SQLite

保存：

Memory

Settings

Pet Status

Skill State

⸻

6. Rendering System

渲染目标

达到现代游戏画质。

支持：

PBR

HDR

Shadow

Environment Light

SSAO

Bloom

Tone Mapping

⸻

光照

支持：

Directional Light

Point Light

IBL

Environment Map

⸻

阴影

支持：

Soft Shadow

Contact Shadow

Dynamic Shadow

⸻

7. Physics System

目标：

70% Reality

100% Cute

⸻

支持：

Gravity

Jump

Landing

Sliding

Collision

Spring

Tail Physics

Ear Physics

Head Tracking

⸻

不追求：

复杂破坏

流体模拟

车辆

角色控制器

⸻

8. Animation System

支持：

Idle

Walk

Run

Jump

Sit

Sleep

Stretch

Eat

Drink

Observe

Tail Swing

Scratch

Wash Face

⸻

支持：

Animation Blend

Animation Layer

Random Idle

Procedural Animation

IK

⸻

9. AI Runtime

Claude 输出：

Intent:
GoSleep

Runtime：

寻找睡觉位置
↓
走过去
↓
播放动画
↓
开启呼吸动画
↓
进入Sleep状态

AI 不关心动画细节。

⸻

10. Skills

Skill 为 Runtime 能力。

例如：

Move()

Jump()

Sit()

Sleep()

Eat()

OpenApp()

LookAtCursor()

FollowCursor()

PlayAnimation()

Speak()

⸻

Claude 只能调用 Skill。

不能直接操作模型。

⸻

11. 桌面世界

建立虚拟三维空间。

             Y
             ↑
             │
─────────────┼──────────── X
            /
           /
          Z

所有对象：

* Dock
* Widget
* 图标
* 文件

全部映射到：

3D World。

⸻

12. Desktop NavMesh

桌面建立 Navigation Mesh。

████ Widget
□□□□□□□□
██ Finder
□□□□□□□□

狐狸：

自动绕开。

⸻

13. Runtime 生命周期

Launch
↓
Load Scene
↓
Load Model
↓
Load Physics
↓
Idle
↓
Behavior Update
↓
Render
↓
Sleep

⸻

14. Claude CLI 生命周期

默认：

关闭。

用户：

点击

↓

启动 Claude

↓

思考

↓

生成 Intent

↓

退出

减少资源占用。

⸻

15. 性能目标

安装包：

20~30MB

Runtime：

70~100MB

CPU：

Idle < 1%

GPU：

5% 左右

启动：

<1 秒

FPS：

60 FPS

Claude：

按需启动

⸻

16. 后续扩展

未来可扩展：

多宠物

多个 AI 同时生活。

⸻

多 Agent

不同人格。

不同能力。

⸻

宠物社交

共享世界。

⸻

AR 模式

RealityKit

Apple Vision Pro

⸻

插件市场

Skill Marketplace

第三方 Skill。

⸻

17. 最终架构

               Claude CLI
                    │
              Intent / Memory
                    │
────────────────────────────────────
          Desktop Runtime
────────────────────────────────────
Behavior AI
↓
Navigation
↓
Physics
↓
Animation
↓
Rendering (Metal)
↓
Transparent Desktop Overlay
↓
macOS Desktop

⸻

18. 设计理念

整个系统遵循：

AI 负责思考。

Behavior 负责决策。

Physics 负责真实。

Animation 负责表达。

Rendering 负责视觉。

最终实现：

一个真正生活在 macOS 桌面中的 AI 生物，而不是一个播放动画的桌宠。