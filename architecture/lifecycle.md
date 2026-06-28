# Lifecycle

> Application lifecycle: Launch → Boot → Idle → Sleep → Shutdown.

---

## State Machine

```
        Launch
          │
          ▼
        ┌─ Boot in progress ─┐
        │                    │
        ▼                    ▼
   Cold Start done      Boot failed
   (first frame)        (graceful error UI)
        │                    │
        ▼                    ▼
        ┌─ Idle (loop running, no behavior task) ─┐
        │                ▲                │
        │                │                ▼
        │           Sleep requested       Movement tick
        │           (no input)            (physics / anim)
        ▼                                    │
        └─ Shutting down ─────── Sleep awakened ─┘
                │
                ▼
        Process exits cleanly
```

---

## Phases of Lifecycle

| Phase | Implementation Phase | Path Triggered |
|---|---|---|
| Launch | Phase 1 | User double-clicks `DesktopPet.app` |
| Boot | Phase 1 | Logger → Config → Window → Modules → Render Surface → Loop |
| Idle | Phase 1 onwards | Default state once loop starts |
| Sleep | Phase 4 — partial, Phase 6 — full | System idle for ≥ 5 min OR user request |
| Movement-tick | Phase 3 onwards | Behavior chooses target motion |
| Shutdown | Phase 1 | Cmd-Q, SIGINT, system shutdown |

---

## Boot Order (Phase 1 closes outline)

1. `Logger.init()` (from `DPFoundation`)
2. `Config.load(...)` (from `DPFoundation`)
3. `Window.attach(view: MTKView)` (from `DPWindow`)
4. `Modules.registerAll([...])` (from `DPRuntime.ModuleManager`)
5. `Renderer.initialize(...)` (from `DPRenderer`)
6. Run-loop begins; `Profiler.shared.start()`

---

## Shutdown Order (reverse)

1. Profiler flushes last window.
2. Renderer releases Metal resources (per `spec-003-runtime.md` Acceptance item 22).
3. Animation/Skinning buffers released.
4. Window detaches.
5. Config persists (Phase 6 onwards).
6. Logger flushes; exit 0.

---

## Status

**Stub**. Phase 1 implements Launch / Boot / Idle-Loop / Shutdown. Sleep / Movement-tick arrive in Phase 4 / Phase 6.
