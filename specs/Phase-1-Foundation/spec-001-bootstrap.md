Status: Approved
Phase: 1 — Foundation
Owner: TBD
-->

# SPEC-001 — Project Bootstrap

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Anchor in repo: `architecture/`, `decisions/`.

---

## 1. Goal

Establish the Swift Package, Xcode project, module layout, build system, logger, and config loader such that any later Work Spec can be authored against a stable foundation in one command (`swift build` for the package, `xcodebuild` for the .app target).

When SPEC-001 is done, a developer (or AI coding tool) can `git clone` the repo, run a single bootstrap script, open `DesktopPet.xcodeproj`, build, and launch `DesktopPet.app`.

---

## 2. Deliverables

- **Swift Package** `desktop-pet-core` containing the engine libraries, buildable on macOS 14+.
  - Modules exposed:
    - `DPRuntime` (lifecycle, module manager)
    - `DPWindow` (NSWindow wrapper, see SPEC-002)
    - `DPRenderer` (Metal renderer entry, see SPEC-002 / Phase 2)
    - `DPAsset` (GLB / KTX2 loaders, async load, cache — SPEC-004)
    - `DPAnimation` (Skeleton + Idle — SPEC-005)
    - `DPProfiler` (Frame Pacing / GPU Time / Memory — SPEC-006)
    - `DPFoundation` (Logger, Config, common types)
  - Module boundaries hardened: no module may import a sibling module except via a published API.
  - All modules expose at least one **mock implementation** for testing.
- **Xcode project** `DesktopPet.xcodeproj` with:
  - App target `DesktopPet` (macOS 14+, Apple Silicon optimized, hardened runtime + entitlements see Decision future)
  - Test target `DesktopPetTests`
  - Single SwiftPM dependency → `desktop-pet-core` package
- **Module Layout doc** (`architecture/module-layout.md`): list each module's responsibility, public types, dependency graph.
- **Logger** (`DPFoundation.Logger`):
  - Levels: trace / debug / info / warn / error.
  - Pluggable sink (stdout for debug, file for default).
  - Read from `OSLog` on macOS — avoids syslog noise.
  - Redacts known sensitive patterns (Claude API keys, file paths under `~/Documents`) — sets up a contract for Phase 7.
- **Config** (`DPFoundation.Config`):
  - YAML or TOML loader from `~/Library/Application Support/DesktopPet/config.yaml`.
  - Schema-validated against a typed structure (no string keys exposed to feature modules).
  - Hot-reload: not in Phase 1; deferred to Phase 8.
- **Build script** `scripts/bootstrap.sh`:
  - Installs `swift-format` (pin to commit).
  - Sets up `.git/hooks/pre-commit` to run `swift-format` + `swift test`.
  - Verifies Mac OS minimum CLI tooling.
- **CI workflow** `.github/workflows/ci.yml` (or equivalent — podman-equivalent if GitHub unavailable): runs `swift build`, `swift test`, then `xcodebuild test` on M-series runner.
- **Lint / format rules** `.swift-format` committed; `swift test` is the entry gate.

---

## 3. Out of Scope

- ❌ Any runtime logic (those are SPEC-002 .. 006).
- ❌ Asset file generation / GLB tooling — assets are checked in.
- ❌ Install / packaging — Phase 9.
- ❌ Telemetry / Crash — Phase 9.
- ❌ Cross-platform support (Linux / Intel Mac) — Phase 9 may revisit; for now, Apple Silicon only.
- ❌ Auto-update of dependencies — manual pin in `Package.swift`.
- ❌ Code signing for distribution — dev signing only in Phase 1.
- ❌ Hot-reload of Config — deferred to Phase 8.

---

## 4. Risk

| Risk | Mitigation |
|---|---|
| SwiftPM ↔ Xcode target binding breaks when adding Metal shaders | Use `resources:` for shader `.metal` files; expose shader compilation via a thin `MTLLibrary` wrapper at app start. |
| Apple's SwiftPM toolchain differs between macOS versions | Pin toolchain in `Package.swift` (`swift-tools-version: 5.10` minimum); CI runs on the pinned image. |
| Logger leakage to OSLog under heavy load | Rate-limit trace-level logs to 100 / s. |
| Config schema drift between Config.swift and config.yaml | Config is regenerated via a Swift `Codable` struct; tests assert round-trip equality. |
| Build script assumes tools at non-standard paths | `scripts/bootstrap.sh` uses `command -v` and exits early with an actionable message. |

---

## 5. Acceptance

### Performance Metrics
- [ ] Cold `swift build` after a clean clone **≤ 90 s** on M-series baseline.
- [ ] Incremental `swift build` after a one-line change **≤ 5 s**.
- [ ] Logger throughput **≥ 50 000 events/s** under burst (synthetic test).
- [ ] Config load **≤ 50 ms** for a 4 KB YAML file.

### Enumerable Use Cases
- [ ] `git clone … && cd desktop-pet && ./scripts/bootstrap.sh && open DesktopPet.xcodeproj` runs end-to-end without manual steps.
- [ ] `swift test` runs and all unit tests pass.
- [ ] `xcodebuild test` runs and all XCTest pass.
- [ ] `swift run` from terminal produces an iTerm-launched sample binary that loads logger + config prints a header line.

### Assertable States
- [ ] `DPFoundation.Logger` rejects unknown log levels via a typed enum.
- [ ] `DPFoundation.Config.decode<T>(_:)` returns Err on schema mismatch with a structured reason (no string parsing).
- [ ] Each module exposes at least one `*Mock` type — verifiable via build-time reflection test.
- [ ] `scripts/bootstrap.sh` returns non-zero exit if a required tool is missing.

### Previous-Phase Regression
- [ ] N/A (Phase 1 origin).

---

## 6. Trace

- Implements `roadmap.md` D-001, D-010.
- Defines the module surface consumed by `spec-002-window.md`, `spec-003-runtime.md`, `spec-004-asset.md`, `spec-005-animation.md`, `spec-006-profiler.md`.
- Architecture doc `architecture/module-layout.md` is created here.
- API docs `api/runtime-api.md`, `api/window-api.md`, `api/asset-api.md`, `api/animation-api.md`, `api/profiler-api.md` seeded here.
