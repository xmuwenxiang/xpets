# spec-001 (Metal Renderer backbone) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Phase-2 Metal renderer backbone — a pass-graph `DPRenderer.Renderer` with `RenderPass` registration, stable order, per-frame `currentFrameIndex`, injected Profiler counter sink, and `Phase1Renderer` rewired to drive it — preserving all Phase-1 invariants.

**Architecture:** New `Renderer` class (device-optional; headless-constructible for CI logic tests) + `RenderPass` protocol / `RenderPassId` / type-erasing `AnyRenderPass`. `Phase1Renderer` kept as the `MTKViewDelegate`/`RendererSurface` shell owning a `Renderer`. Profiler coupling is via an injected `counterSink` closure (NOT a direct `Profiler.shared` call) because `DPProfiler` already depends on `DPRenderer` — a direct call would be a circular dependency. Modules register a `ClearPass` during the module-boot window.

**Tech Stack:** Swift 5.10 / SwiftPM / Metal 3 (on Metal-4-capable M4) / XCTest.

**Branch:** `phase-2/spec-001-renderer` (from `main` at commit `0ede333`).

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `scripts/phase2-spec-lint.sh` | modify | Loosen check 3 to allow `Status: Approved\|Implementing\|Done`. |
| `desktop-pet-core/Package.swift` | modify | Add `DPRendererTests` test target (deps: `DPRenderer`, `DPProfiler`). |
| `desktop-pet-core/Sources/DPRenderer/RenderPass.swift` | new | `RenderPassId`, `RenderPass` protocol, `AnyRenderPass` type-erasure. |
| `desktop-pet-core/Sources/DPRenderer/Renderer.swift` | modify | Add `Renderer` class + `RendererError`; refactor `Phase1Renderer` to own a `Renderer`; extend `RendererSurface` with `passGraph`. |
| `desktop-pet-core/Sources/DPRenderer/RenderPasses.swift` | new | `ClearPass` (default root, no-op encode, `gpuLabel = "clear"`). |
| `desktop-pet-core/Sources/DPRuntime/Application.swift` | modify | Register `ClearPass` via `RenderMeshModule` at boot. |
| `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift` | new | CI logic tests (headless). |
| `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift` | new | Local-M4 device tests (env-guarded; skip on CI). |
| `api/renderer-api.md` | new | Order semantics, threading, retain-cycle prohibition. |
| `specs/Phase-2-Rendering/spec-001-metal-renderer.md` | modify | `Status: Approved → Implementing → Done`. |
| `specs/Phase-2-Rendering/findings.md` | new | spec↔code drift log. |

---

## Task 1: Loosen phase2-spec-lint to allow Implementing / Done

**Files:**
- Modify: `scripts/phase2-spec-lint.sh` (check 3, the `^Status: Approved$` line)

The review-round lint requires `^Status: Approved$` for every `spec-*.md`. Implementation transitions spec-001 to `Implementing` then `Done`, which would break the lint. Loosen first.

- [ ] **Step 1: Edit check 3**

In `scripts/phase2-spec-lint.sh`, replace:
```
  if ! grep -q '^Status: Approved$' "$spec"; then
    echo "::error::$spec missing 'Status: Approved' header line"
```
with:
```
  if ! grep -qE '^Status: (Approved|Implementing|Done)$' "$spec"; then
    echo "::error::$spec missing 'Status: Approved|Implementing|Done' header line"
```

- [ ] **Step 2: Verify lint still green now (all 5 specs are Approved)**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: `phase2-spec-lint: PASS`, `exit=0`.

- [ ] **Step 3: Verify the loosened regex accepts Implementing (temporary probe)**

Run: `sed -i '' 's/^Status: Approved$/Status: Implementing/' specs/Phase-2-Rendering/spec-001-metal-renderer.md && ./scripts/phase2-spec-lint.sh; echo "exit=$?"; sed -i '' 's/^Status: Implementing$/Status: Approved/' specs/Phase-2-Rendering/spec-001-metal-renderer.md`
Expected: `phase2-spec-lint: PASS`, `exit=0` (Implementing now accepted); then spec-001 restored to Approved.

- [ ] **Step 4: Commit**

```bash
git add scripts/phase2-spec-lint.sh
git commit -m "ci(phase-2): allow spec Status Implementing|Done in lint

Implementation rounds transition spec status Approved→Implementing→Done;
the review-round lint only allowed Approved. Loosen check 3 to accept
all three implementation-or-beyond statuses.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: RenderPassId + Renderer init (scaffold tests; spec-001 → Implementing)

**Files:**
- Create: `desktop-pet-core/Sources/DPRenderer/RenderPass.swift`
- Modify: `desktop-pet-core/Sources/DPRenderer/Renderer.swift` (add `Renderer` class)
- Modify: `desktop-pet-core/Package.swift` (add `DPRendererTests` target)
- Create: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`
- Modify: `specs/Phase-2-Rendering/spec-001-metal-renderer.md` (Status → Implementing)

- [ ] **Step 1: Add the test target to Package.swift**

In `desktop-pet-core/Package.swift`, after the `DPProfilerTests` testTarget block (the last entry before the closing `]` of `targets:`), insert:
```swift
        ,
        .testTarget(
            name: "DPRendererTests",
            dependencies: ["DPRenderer", "DPProfiler", "DPFoundation"],
            path: "Tests/DPRendererTests"
        )
```
(The leading `,` continues the array; place it immediately after the `DPProfilerTests` block's closing `)` and before the `]`.)

- [ ] **Step 2: Write the failing test**

Create `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`:
```swift
import XCTest
import DPRenderer

final class RendererInitTests: XCTestCase {
    func testRendererInitDefaults() {
        let r = Renderer(device: nil)
        XCTAssertEqual(r.currentFrameIndex, 0)
        XCTAssertFalse(r.isRunning)
        XCTAssertEqual(r.registeredPassIDs, [])
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --package-path desktop-pet-core --filter RendererInitTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'Renderer' in scope` (and `RenderPassId` for later tasks). Build error.

- [ ] **Step 4: Create RenderPass.swift with RenderPassId**

Create `desktop-pet-core/Sources/DPRenderer/RenderPass.swift`:
```swift
import Metal

/// Stable identifier for a registered render pass. Hashable + Sendable so it can
/// be used as a Set element and cross the Renderer thread boundary.
public struct RenderPassId: Hashable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    /// The root anchor — the first pass conceptually attaches here.
    public static let root = RenderPassId("root")
}
```

- [ ] **Step 5: Add the minimal Renderer class**

In `desktop-pet-core/Sources/DPRenderer/Renderer.swift`, append (after the existing `RendererMock` class, at end of file):
```swift
// MARK: - Phase 2 Pass Graph

/// Production renderer entry path. Owns the ordered pass list, the per-frame
/// index, and (when a device is attached) the Metal command queue. Constructible
/// without an MTLDevice for headless CI logic tests.
public final class Renderer: @unchecked Sendable {
    private let device: MTLDevice?
    private var commandQueue: MTLCommandQueue?

    public private(set) var currentFrameIndex: UInt64 = 0
    public private(set) var isRunning = false

    private var passes: [AnyRenderPass] = []
    private var pendingRemovals: Set<RenderPassId> = []
    private var pendingDrops: Set<RenderPassId> = []

    /// Snapshot of registered pass IDs in stable execution order.
    public var registeredPassIDs: [RenderPassId] { passes.map { $0.id } }

    /// Injected counter sink. The Runtime wires this to `Profiler.shared.record`
    /// (Renderer cannot import DPProfiler — DPProfiler already depends on
    /// DPRenderer, so a direct call would be a circular dependency).
    public var counterSink: ((String, Double) -> Void)?

    public init(device: MTLDevice? = nil) {
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
    }

    /// Attach a real device post-init (used by Phase1Renderer.prepare, which runs
    /// after module-boot). No-op once the Renderer has started ticking.
    public func attach(device: MTLDevice) {
        guard !isRunning else { return }
        self.commandQueue = device.makeCommandQueue()
    }
}
```

Note: `AnyRenderPass` is referenced by `passes` but not yet defined — the build will still fail until Task 3. To make Task 2 green independently, temporarily comment the `passes`/`pendingRemovals`/`pendingDrops` lines and `registeredPassIDs` returning `[]`. **Simpler:** define a stub `AnyRenderPass` now.

Replace the `Renderer` body's pass-storage lines — actually, add this stub type at the end of `RenderPass.swift` so the file compiles:
```swift
/// Type-erased RenderPass box. Fully implemented in Task 3; this stub lets
/// Task 2's init test compile (no pass storage exercised yet).
public final class AnyRenderPass: @unchecked Sendable {
    public let id: RenderPassId
    public let gpuLabel: String
    public init(_ id: RenderPassId = RenderPassId("stub"), gpuLabel: String = "stub") {
        self.id = id
        self.gpuLabel = gpuLabel
    }
    func encode(into commandBuffer: MTLCommandBuffer) throws -> RenderPassId { id }
}
```
And in the `Renderer` class, the `passes: [AnyRenderPass]` line now type-checks. (`registeredPassIDs` returns `passes.map { $0.id }` → `[]` when empty.)

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter RendererInitTests 2>&1 | tail -20`
Expected: PASS — `testRendererInitTests` 1 test, 0 failures. (`AnyRenderPass` stub + `Renderer` compile; init defaults hold.)

- [ ] **Step 7: Set spec-001 Status → Implementing**

In `specs/Phase-2-Rendering/spec-001-metal-renderer.md`, change the header line:
```
Status: Approved
```
to:
```
Status: Implementing
```
(Per `00-spec-conventions.md §7`: Approved→Implementing is valid once a failed test exists for the first deliverable — Step 3's red test satisfies this.)

- [ ] **Step 8: Run lint (should still pass — Implementing now allowed)**

Run: `./scripts/phase2-spec-lint.sh; echo "exit=$?"`
Expected: `phase2-spec-lint: PASS`, `exit=0`.

- [ ] **Step 9: Commit**

```bash
git add desktop-pet-core/Package.swift \
        desktop-pet-core/Sources/DPRenderer/RenderPass.swift \
        desktop-pet-core/Sources/DPRenderer/Renderer.swift \
        desktop-pet-core/Tests/DPRendererTests/RendererTests.swift \
        specs/Phase-2-Rendering/spec-001-metal-renderer.md
git commit -m "impl(phase-2/spec-001): Renderer pass-graph skeleton + RenderPassId

Add DPRendererTests target; RenderPassId; Renderer (device-optional)
with currentFrameIndex/isRunning/registeredPassIDs + AnyRenderPass stub.
spec-001 Status: Approved → Implementing (first red test satisfied §7).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: RenderPass protocol + AnyRenderPass + register/unregister order

**Files:**
- Modify: `desktop-pet-core/Sources/DPRenderer/RenderPass.swift` (real `RenderPass` protocol + `AnyRenderPass`)
- Modify: `desktop-pet-core/Sources/DPRenderer/Renderer.swift` (`registerPass` / `unregisterPass`)
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift` (order tests)

- [ ] **Step 1: Write the failing tests**

Append to `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`:
```swift
import Metal

/// Minimal test pass — Context = Void, encode is a no-op (headless tests do not
/// exercise encode; device tests in RendererDeviceTests do).
private final class TestPass: RenderPass {
    typealias Context = Void
    let id: RenderPassId
    var gpuLabel: String { "test.\(id.raw)" }
    init(_ raw: String) { self.id = RenderPassId(raw) }
    func encode(into commandBuffer: MTLCommandBuffer, context: Void) throws -> RenderPassId { id }
}

final class RendererRegistryTests: XCTestCase {
    func testRegisterOrderIsStable() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        try r.registerPass(TestPass("B"), context: ())
        try r.registerPass(TestPass("C"), context: ())
        try r.registerPass(TestPass("D"), context: ())
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A"), RenderPassId("B"), RenderPassId("C"), RenderPassId("D")])
    }

    func testUnregisterMiddleKeepsOrder() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        try r.registerPass(TestPass("B"), context: ())
        try r.registerPass(TestPass("C"), context: ())
        try r.registerPass(TestPass("D"), context: ())
        r.unregisterPass(id: RenderPassId("B"))
        // Removal is deferred to next tick (released on next present tick).
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A"), RenderPassId("B"), RenderPassId("C"), RenderPassId("D")])
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A"), RenderPassId("C"), RenderPassId("D")])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path desktop-pet-core --filter RendererRegistryTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'RenderPass' in scope` (protocol not defined yet) and/or `registerPass` missing.

- [ ] **Step 3: Implement RenderPass protocol + real AnyRenderPass**

Replace the `AnyRenderPass` stub in `desktop-pet-core/Sources/DPRenderer/RenderPass.swift` (delete the stub block from Step 5 of Task 2) and add the protocol + real box. The final `RenderPass.swift` content:
```swift
import Metal

/// Stable identifier for a registered render pass. Hashable + Sendable so it can
/// be used as a Set element and cross the Renderer thread boundary.
public struct RenderPassId: Hashable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    /// The root anchor — the first pass conceptually attaches here.
    public static let root = RenderPassId("root")
}

/// A single render pass. `associatedtype Context` is the pass's own input type;
/// the Renderer stores heterogeneous passes via `AnyRenderPass` type-erasure
/// (context is captured at registration time).
public protocol RenderPass: AnyObject {
    associatedtype Context
    var id: RenderPassId { get }
    var gpuLabel: String { get }
    /// Encode into the given command buffer. Throwing here is caught by the
    /// Renderer: the pass is dropped after the frame and ticking continues
    /// (Loop-survives invariant, Phase-1 spec-003 §5).
    func encode(into commandBuffer: MTLCommandBuffer, context: Context) throws -> RenderPassId
}

/// Type-erased RenderPass. Holds the pass and its captured context; exposes a
/// non-generic `encode(into:)`.
public final class AnyRenderPass: @unchecked Sendable {
    public let id: RenderPassId
    public let gpuLabel: String
    private let _encode: (MTLCommandBuffer) throws -> RenderPassId

    public init<P: RenderPass>(_ pass: P, context: P.Context) {
        self.id = pass.id
        self.gpuLabel = pass.gpuLabel
        self._encode = { commandBuffer in try pass.encode(into: commandBuffer, context: context) }
    }

    public func encode(into commandBuffer: MTLCommandBuffer) throws -> RenderPassId {
        try _encode(commandBuffer)
    }
}
```

- [ ] **Step 4: Implement registerPass / unregisterPass / tick in Renderer**

In `desktop-pet-core/Sources/DPRenderer/Renderer.swift`, add these methods to the `Renderer` class (inside the class body, after `attach`):
```swift
    /// Register a pass. Only legal before the first tick (module-boot window).
    /// `after` anchors insertion immediately after the named pass; nil appends.
    public func registerPass<P: RenderPass>(
        _ pass: P,
        context: P.Context,
        after anchor: RenderPassId? = nil
    ) throws {
        guard !isRunning else { throw RendererError.alreadyRunning }
        let id = pass.id
        guard !passes.contains(where: { $0.id == id }) else {
            throw RendererError.duplicatePassID(id)
        }
        let box = AnyRenderPass(pass, context: context)
        if let anchor, let idx = passes.firstIndex(where: { $0.id == anchor }) {
            passes.insert(box, at: idx + 1)
        } else {
            passes.append(box)
        }
    }

    /// Schedule removal; the box is released on the next tick (present-tick drain)
    /// so no use-after-free mid-frame.
    public func unregisterPass(id: RenderPassId) {
        pendingRemovals.insert(id)
    }

    /// Advance one frame. Increments currentFrameIndex, flips isRunning, drains
    /// pending removals, encodes passes into `commandBuffer` if provided, emits
    /// a Counter per pass via `counterSink`, and drops any pass that threw.
    public func tick(dt: Double, into commandBuffer: MTLCommandBuffer? = nil) {
        if !pendingRemovals.isEmpty {
            passes.removeAll { pendingRemovals.contains($0.id) }
            pendingRemovals.removeAll()
        }
        currentFrameIndex &+= 1
        isRunning = true
        for box in passes {
            if let cb = commandBuffer {
                do { _ = try box.encode(into: cb) }
                catch { pendingDrops.insert(box.id) }
            }
            counterSink?(box.gpuLabel, 0)
        }
        if !pendingDrops.isEmpty {
            passes.removeAll { pendingDrops.contains($0.id) }
            pendingDrops.removeAll()
        }
    }
```
Also add the `RendererError` enum at the top of the `// MARK: - Phase 2 Pass Graph` section (before `Renderer`):
```swift
public enum RendererError: Error, Equatable {
    case alreadyRunning
    case duplicatePassID(RenderPassId)
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path desktop-pet-core --filter RendererRegistryTests 2>&1 | tail -20`
Expected: PASS — 2 tests, 0 failures.

- [ ] **Step 6: Run full test suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: all tests pass (Phase-1 30 + RendererInit + 2 registry = 33).

- [ ] **Step 7: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/RenderPass.swift \
        desktop-pet-core/Sources/DPRenderer/Renderer.swift \
        desktop-pet-core/Tests/DPRendererTests/RendererTests.swift
git commit -m "impl(phase-2/spec-001): RenderPass protocol + register/unregister order

RenderPass (associatedtype Context) + AnyRenderPass type-erasure;
Renderer.registerPass/unregisterPass/tick; RendererError. Deferred
removal on next tick. Order tests green.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: duplicatePassID error

**Files:**
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`

(`RendererError.duplicatePassID` + the guard were implemented in Task 3 Step 4; this task adds the test and verifies.)

- [ ] **Step 1: Write the failing test**

Append to `RendererTests.swift`:
```swift
final class RendererDuplicateIDTests: XCTestCase {
    func testDuplicatePassIDThrowsAndPreservesOriginal() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        XCTAssertThrowsError(try r.registerPass(TestPass("A"), context: ())) { error in
            guard case .duplicatePassID(let id) = error as? RendererError else {
                XCTFail("expected duplicatePassID, got \(error)"); return
            }
            XCTAssertEqual(id, RenderPassId("A"))
        }
        // Original preserved exactly once.
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A")])
    }
}
```

- [ ] **Step 2: Run test to verify it passes (behavior already implemented)**

Run: `swift test --package-path desktop-pet-core --filter RendererDuplicateIDTests 2>&1 | tail -20`
Expected: PASS — 1 test, 0 failures. (If it fails, the Task 3 guard has a bug — fix the guard, not the test.)

- [ ] **Step 3: Commit**

```bash
git add desktop-pet-core/Tests/DPRendererTests/RendererTests.swift
git commit -m "test(phase-2/spec-001): duplicatePassID throws, original preserved

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: alreadyRunning error

**Files:**
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `RendererTests.swift`:
```swift
final class RendererAlreadyRunningTests: XCTestCase {
    func testRegisterAfterFirstTickThrowsAlreadyRunning() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        r.tick(dt: 1.0 / 60.0)   // first tick → isRunning = true
        XCTAssertThrowsError(try r.registerPass(TestPass("B"), context: ())) { error in
            guard case .alreadyRunning = error as? RendererError else {
                XCTFail("expected alreadyRunning, got \(error)"); return
            }
        }
        // B was NOT registered.
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A")])
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter RendererAlreadyRunningTests 2>&1 | tail -20`
Expected: PASS — 1 test, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add desktop-pet-core/Tests/DPRendererTests/RendererTests.swift
git commit -m "test(phase-2/spec-001): register after first tick → alreadyRunning

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: tick increments currentFrameIndex + sets isRunning (headless)

**Files:**
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `RendererTests.swift`:
```swift
final class RendererFrameIndexTests: XCTestCase {
    func testTickIncrementsFrameIndexAndSetsRunning() {
        let r = Renderer(device: nil)
        XCTAssertEqual(r.currentFrameIndex, 0)
        XCTAssertFalse(r.isRunning)
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.currentFrameIndex, 1)
        XCTAssertTrue(r.isRunning)
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.currentFrameIndex, 2)
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.currentFrameIndex, 3)
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter RendererFrameIndexTests 2>&1 | tail -20`
Expected: PASS — 1 test, 0 failures. (`tick` implemented in Task 3 Step 4 increments `currentFrameIndex` and sets `isRunning`.)

- [ ] **Step 3: Commit**

```bash
git add desktop-pet-core/Tests/DPRendererTests/RendererTests.swift
git commit -m "test(phase-2/spec-001): tick increments currentFrameIndex, sets isRunning

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: unregister releases the pass after drain (weak ref)

**Files:**
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `RendererTests.swift`:
```swift
final class RendererWeakReleaseTests: XCTestCase {
    func testUnregisterReleasesPassAfterDrain() throws {
        let r = Renderer(device: nil)
        weak var weakPass: TestPass?
        let id = RenderPassId("A")
        autoreleasepool {
            let pass = TestPass("A")
            weakPass = pass
            try? r.registerPass(pass, context: ())
        }
        // The AnyRenderPass box (closure capture) still holds the pass.
        XCTAssertNotNil(weakPass)
        r.unregisterPass(id: id)
        // Not yet drained.
        XCTAssertNotNil(weakPass)
        r.tick(dt: 1.0 / 60.0)  // drain
        XCTAssertNil(weakPass)
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter RendererWeakReleaseTests 2>&1 | tail -20`
Expected: PASS — 1 test, 0 failures. (The deferred-removal in `tick` removes the box; with no other strong ref, the pass deallocates.)

- [ ] **Step 3: Commit**

```bash
git add desktop-pet-core/Tests/DPRendererTests/RendererTests.swift
git commit -m "test(phase-2/spec-001): unregister releases pass after drain (weak ref nil)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: counterSink records Profiler Counter per pass (headless)

**Files:**
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `RendererTests.swift`:
```swift
import DPProfiler

final class RendererCounterSinkTests: XCTestCase {
    func testTickRecordsCounterPerPassViaSink() throws {
        let r = Renderer(device: nil)
        Profiler.shared.reset()
        defer { Profiler.shared.reset() }
        r.counterSink = { name, value in
            Profiler.shared.record(Counter(name: name, value: value))
        }
        try r.registerPass(TestPass("alpha"), context: ())
        try r.registerPass(TestPass("beta"), context: ())
        r.tick(dt: 1.0 / 60.0)
        XCTAssertNotNil(Profiler.shared.counters["test.alpha"])
        XCTAssertNotNil(Profiler.shared.counters["test.beta"])
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter RendererCounterSinkTests 2>&1 | tail -20`
Expected: PASS — 1 test, 0 failures. (`tick` calls `counterSink?(box.gpuLabel, 0)` per pass; the sink records into Profiler.)

- [ ] **Step 3: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: all green (Phase-1 30 + 8 spec-001 logic tests = 38).

- [ ] **Step 4: Commit**

```bash
git add desktop-pet-core/Tests/DPRendererTests/RendererTests.swift
git commit -m "test(phase-2/spec-001): counterSink records Profiler Counter per pass

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Device-guarded tests (local M4; skip on CI)

**Files:**
- Create: `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift`

These tests need a real `MTLDevice` (encode path). They are guarded by the `XPETS_GPU_TESTS` env var: CI does not set it → skipped; local M4 run `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests`.

- [ ] **Step 1: Write the device tests**

Create `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift`:
```swift
import XCTest
import Metal
import DPRenderer

final class RendererDeviceTests: XCTestCase {
    private func skipUnlessGPU() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["XPETS_GPU_TESTS"] != nil,
            "GPU test — set XPETS_GPU_TESTS=1 to run locally on M4 (skipped on CI per execution-plan)"
        )
    }

    /// Encode order matches registered order. A TestPass appends its id to a
    /// shared recorder when encode is invoked.
    func testEncodeOrderMatchesRegisteredOrder() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            try XCTSkip("no Metal device")
        }
        final class RecordingPass: RenderPass {
            typealias Context = Recorder
            let id: RenderPassId
            var gpuLabel: String { "rec.\(id.raw)" }
            private let recorder: Recorder
            init(_ raw: String, recorder: Recorder) { self.id = RenderPassId(raw); self.recorder = recorder }
            func encode(into commandBuffer: MTLCommandBuffer, context: Recorder) throws -> RenderPassId {
                context.order.append(id); return id
            }
        }
        final class Recorder { var order: [RenderPassId] = [] }
        let recorder = Recorder()
        let r = Renderer(device: device)
        try r.registerPass(RecordingPass("A", recorder: recorder), context: recorder)
        try r.registerPass(RecordingPass("B", recorder: recorder), context: recorder)
        try r.registerPass(RecordingPass("C", recorder: recorder), context: recorder)
        let buffer = queue.makeCommandBuffer()!
        r.tick(dt: 1.0 / 60.0, into: buffer)
        buffer.commit()
        XCTAssertEqual(recorder.order, [RenderPassId("A"), RenderPassId("B"), RenderPassId("C")])
    }

    /// A pass that throws inside encode is dropped after the frame; the Renderer
    /// keeps ticking (Loop-survives invariant).
    func testThrowingPassDroppedAndLoopSurvives() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            try XCTSkip("no Metal device")
        }
        enum Boom: Error { case boom }
        final class ThrowingPass: RenderPass {
            typealias Context = Void
            let id = RenderPassId("boom")
            var gpuLabel: String { "boom" }
            func encode(into commandBuffer: MTLCommandBuffer, context: Void) throws -> RenderPassId { throw Boom.boom }
        }
        final class OKPass: RenderPass {
            typealias Context = Void
            let id = RenderPassId("ok")
            var gpuLabel: String { "ok" }
            func encode(into commandBuffer: MTLCommandBuffer, context: Void) throws -> RenderPassId { id }
        }
        let r = Renderer(device: device)
        try r.registerPass(ThrowingPass(), context: ())
        try r.registerPass(OKPass(), context: ())
        // Frame 1: boom throws → dropped after frame; ok survives.
        let b1 = queue.makeCommandBuffer()!
        r.tick(dt: 1.0 / 60.0, into: b1)
        b1.commit()
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("ok")])
        // Frame 2: loop survives, ok still ticks.
        let b2 = queue.makeCommandBuffer()!
        r.tick(dt: 1.0 / 60.0, into: b2)
        b2.commit()
        XCTAssertEqual(r.currentFrameIndex, 2)
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("ok")])
    }

    /// no-op Pass per-frame dispatch P99 ≤ 0.5 ms over 600 frames (CPU-dispatch
    /// proxy: makeCommandBuffer + encode + commit). Recorded as local baseline.
    func testNoopPassDispatchP99UnderBudget() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            try XCTSkip("no Metal device")
        }
        final class NoopPass: RenderPass {
            typealias Context = Void
            let id = RenderPassId("noop")
            var gpuLabel: String { "noop" }
            func encode(into commandBuffer: MTLCommandBuffer, context: Void) throws -> RenderPassId { id }
        }
        let r = Renderer(device: device)
        try r.registerPass(NoopPass(), context: ())
        var samples: [Double] = []
        samples.reserveCapacity(600)
        for _ in 0..<600 {
            let buffer = queue.makeCommandBuffer()!
            let start = CFAbsoluteTimeGetCurrent()
            r.tick(dt: 1.0 / 60.0, into: buffer)
            buffer.commit()
            samples.append((CFAbsoluteTimeGetCurrent() - start) * 1000.0)
        }
        samples.sort()
        let p99 = samples[Int(Double(samples.count - 1) * 0.99)]
        // Assert + record; the value is also written to acceptance.md evidence.
        XCTAssertLessThanOrEqual(p99, 0.5, "no-op dispatch P99 \(p99)ms exceeds 0.5ms budget")
    }
}
```

- [ ] **Step 2: Run device tests locally on M4 (env-gated)**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests 2>&1 | tail -20`
Expected: PASS — 3 tests, 0 failures (on M4). Record the no-op P99 value printed (add a print or read from a subsequent `--verbose` run) into `acceptance.md` evidence in Task 11.

- [ ] **Step 3: Verify CI-skip behavior (no env var → skipped)**

Run: `swift test --package-path desktop-pet-core --filter RendererDeviceTests 2>&1 | tail -20`
Expected: 3 tests skipped (`XCTSkip`), 0 failures — CI hermetic.

- [ ] **Step 4: Commit**

```bash
git add desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift
git commit -m "test(phase-2/spec-001): device tests (encode order, throw→drop, P99)

Env-gated by XPETS_GPU_TESTS (skipped on CI; local M4 baseline). P99 ≤ 0.5ms.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: ClearPass + Phase1Renderer shell + RendererSurface.passGraph + Application wiring

**Files:**
- Create: `desktop-pet-core/Sources/DPRenderer/RenderPasses.swift`
- Modify: `desktop-pet-core/Sources/DPRenderer/Renderer.swift` (`Phase1Renderer` owns `Renderer`; `RendererSurface` + `RendererMock` gain `passGraph`)
- Modify: `desktop-pet-core/Sources/DPRuntime/Application.swift` (`RenderMeshModule` registers `ClearPass` at boot)

- [ ] **Step 1: Create ClearPass**

Create `desktop-pet-core/Sources/DPRenderer/RenderPasses.swift`:
```swift
import Metal

/// The default root pass. In spec-001 its encode is a no-op (the on-screen clear
/// is still performed by Phase1Renderer's existing render path, preserving the
/// Phase-1 visual). spec-002+ replaces this with real PBR passes that do GPU
/// work into the view's command buffer.
public final class ClearPass: RenderPass {
    public typealias Context = Void
    public let id: RenderPassId = .root
    public var gpuLabel: String { "clear" }
    public init() {}
    public func encode(into commandBuffer: MTLCommandBuffer, context: Void) throws -> RenderPassId { id }
}
```

- [ ] **Step 2: Extend RendererSurface + RendererMock with passGraph**

In `desktop-pet-core/Sources/DPRenderer/Renderer.swift`, add a `passGraph` requirement to the `RendererSurface` protocol:
```swift
public protocol RendererSurface: AnyObject {
    var hostView: NSView { get }
    /// The pass-graph owner (Phase 2). Shells expose their inner Renderer so
    /// modules can register passes during the module-boot window.
    var passGraph: Renderer { get }
    func prepare(device: MTLDevice, scaleFactor: Double)
    func renderFrame(into view: MTKView, dt: Double)
    func shutdown()
}
```
Add to `RendererMock` (the existing mock class) a stored `passGraph`:
```swift
public final class RendererMock: RendererSurface {
    public let hostView: NSView
    public let passGraph = Renderer(device: nil)   // headless, for Application/Scene tests
    public private(set) var framesRendered = 0
    public var scaleFactorOnPrepare: Double = 1.0
    public init() { self.hostView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 320)) }
    public func prepare(device: MTLDevice, scaleFactor: Double) { self.scaleFactorOnPrepare = scaleFactor }
    public func renderFrame(into view: MTKView, dt: Double) { framesRendered += 1 }
    public func shutdown() { framesRendered = 0 }
}
```
(Replace the existing `RendererMock` body with the above — only addition is the `passGraph` property and the protocol conformance now requires it.)

- [ ] **Step 3: Make Phase1Renderer own a Renderer and drive tick**

In `desktop-pet-core/Sources/DPRenderer/Renderer.swift`, modify the `Phase1Renderer` class:
- Add a stored property: `public let passGraph = Renderer(device: nil)`.
- In `prepare(device:scaleFactor:)`, after setting `self.device`, call `passGraph.attach(device: device)` and wire the counter sink to forward to Profiler (Phase1Renderer may import DPProfiler? No — DPRenderer cannot import DPProfiler. The sink wiring is done in Application, which can. So leave `passGraph.counterSink` nil here; Application wires it.). So just add `passGraph.attach(device: device)` in `prepare`.
- In `renderFrame(into view: dt:)`, call `passGraph.tick(dt: dt, into: nil)` at the top of the method (before the existing clear/present logic). This advances `currentFrameIndex` and emits the "clear" Counter every frame. The existing clear-color + present logic stays unchanged (Phase-1 visual preserved). Because `into: nil`, no encode runs (ClearPass is a no-op anyway).

Concretely, in `prepare(device:scaleFactor:)` add inside the `if prepared { return }` guard's body, after `self.commandQueue = device.makeCommandQueue()`:
```swift
        passGraph.attach(device: device)
```
And in `renderFrame(into view: MTKView, dt: Double)`, add as the first line after `guard prepared else { return }`:
```swift
        passGraph.tick(dt: dt, into: nil)
```

- [ ] **Step 4: Wire RenderMeshModule to register ClearPass at boot**

In `desktop-pet-core/Sources/DPRuntime/Application.swift`:
(a) Change `RenderMeshModule` to hold a passGraph handle:
```swift
final class RenderMeshModule: RuntimeModule {
    let name = "RenderMesh"
    let dependencies: [String] = []
    private let passGraph: DPRenderer.Renderer
    init(passGraph: DPRenderer.Renderer) { self.passGraph = passGraph }
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {
        // Phase 2 spec-001: register the default root ClearPass during the
        // module-boot window (registration is illegal after the first tick).
        try? passGraph.registerPass(DPRenderer.ClearPass(), context: ())
    }
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}
```
(b) In `Application.run()`, change the registration call:
```swift
        try moduleManager.register(RenderMeshModule(passGraph: renderer.passGraph))
```
(c) Wire the counter sink to Profiler. In `Application.run()`, after `renderer.prepare(device:scaleFactor:)` (step 3 of run), add:
```swift
        renderer.passGraph.counterSink = { name, value in
            Profiler.shared.record(DPProfiler.Counter(name: name, value: value))
        }
```
(Application depends on both DPRenderer and DPProfiler, so this wiring is legal here.)

- [ ] **Step 5: Run full test suite (Phase-1 regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -10`
Expected: all green — Phase-1 30 tests still pass (RendererMock now exposes passGraph; Scene/Application tests unaffected) + 8 spec-001 logic tests + 3 device tests skipped = no failures.

- [ ] **Step 6: Run device tests locally to confirm ClearPass counter + frame advance end-to-end**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests 2>&1 | tail -10`
Expected: 3 device tests pass.

- [ ] **Step 7: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/RenderPasses.swift \
        desktop-pet-core/Sources/DPRenderer/Renderer.swift \
        desktop-pet-core/Sources/DPRuntime/Application.swift
git commit -m "impl(phase-2/spec-001): wire Renderer into app — ClearPass + shell + sink

ClearPass (root, no-op encode); Phase1Renderer owns a Renderer, drives
tick per frame (frameIndex + 'clear' counter), Phase-1 visual unchanged;
RendererSurface.passGraph; RenderMeshModule registers ClearPass at boot;
Application wires counterSink → Profiler.shared.record. Phase-1 30/30 green.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: api/renderer-api.md + spec-001 Done + findings + acceptance evidence

**Files:**
- Create: `api/renderer-api.md`
- Create: `specs/Phase-2-Rendering/findings.md`
- Modify: `specs/Phase-2-Rendering/acceptance.md` (Evidence rows)
- Modify: `specs/Phase-2-Rendering/spec-001-metal-renderer.md` (Status → Done)

- [ ] **Step 1: Write api/renderer-api.md**

Create `api/renderer-api.md`:
```markdown
# Renderer API (Phase 2 — spec-001)

> The Metal renderer pass-graph. Implements `specs/Phase-2-Rendering/spec-001-metal-renderer.md`.

## Surface

`DPRenderer.Renderer` — the pass-graph owner. Constructible with `MTLDevice?` (nil = headless for CI logic tests).

| Member | Purpose |
|---|---|
| `init(device: MTLDevice? = nil)` | Boot. Device optional; `attach(device:)` fills it post-boot. |
| `var currentFrameIndex: UInt64` | Monotonic per-frame counter; 0 at init, +1 per `tick`. |
| `var isRunning: Bool` | False until first `tick`; gates `registerPass`. |
| `var registeredPassIDs: [RenderPassId]` | Stable execution-order snapshot. |
| `var counterSink: ((String, Double) -> Void)?` | Injected Profiler sink (Renderer cannot import DPProfiler — circular dep). Runtime wires to `Profiler.shared.record`. |
| `registerPass(_:context:after:)` | Register during module-boot window only. `after` anchors insertion. |
| `unregisterPass(id:)` | Deferred release on next `tick`. |
| `tick(dt:into:)` | Advance frame; encode passes into the given `MTLCommandBuffer` if provided; emit Counter per pass. |

## Order semantics

- Pass execution order = registration order; stable across frames.
- `unregisterPass` is deferred to the next `tick` (no use-after-free mid-frame).
- A pass whose `encode` throws is dropped after the frame; ticking continues (Loop-survives invariant, Phase-1 spec-003 §5).

## Errors

`RendererError.alreadyRunning` — register after first `tick`. `RendererError.duplicatePassID(RenderPassId)` — same ID twice; original preserved.

## Threading contract

- Single Renderer thread. `RenderPass.Context` must be `Sendable` if it crosses threads.
- `MTLCommandBuffer` retain-cycle prohibition: passes must not retain the command buffer beyond the `tick` in which it was provided; the Runtime commits the buffer each frame.

## spec ↔ code drift (see findings.md)

- `drawClear(_:)` (spec) → `ClearPass` root pass (no on-screen clear duty in spec-001; Phase-1 clear stays in `Phase1Renderer.renderFrame`).
- `Profiler.shared.recordCounter` (spec) → `counterSink` injection → `Profiler.shared.record(_:)` (circular-dep avoidance).
- `tick(_:)` (spec) → `tick(dt:into:)` (default `into: nil` = headless).
- `registerPass(_:after:)` (spec) → `registerPass(_:context:after:)` (context captured at registration for type-erased storage).
```

- [ ] **Step 2: Write findings.md (spec ↔ code drift log)**

Create `specs/Phase-2-Rendering/findings.md`:
```markdown
# Phase 2 — Findings (spec ↔ code drift)

> Logged during Round 2 implementation. Each entry: spec text → code reality → rationale.

## spec-001

| Spec text | Code reality | Rationale |
|---|---|---|
| `DPRenderer.Renderer.drawClear(_:)` | No such method existed in Phase 1 (only `Phase1Renderer.renderFrame`). spec-001 introduces `Renderer` + `ClearPass`. The on-screen clear stays in `Phase1Renderer.renderFrame` for spec-001; `ClearPass.encode` is a no-op. | spec was written against an idealized API; minimal-churn reconciliation (Option A design). |
| `Profiler.shared.recordCounter` | `Profiler.shared.record(_ counter: Counter)` is the actual API. `Renderer` does not call it directly — `DPProfiler` already depends on `DPRenderer`, so a direct call would be a circular dependency. `Renderer.counterSink: ((String, Double) -> Void)?` is injected; `Application` wires it to `Profiler.shared.record`. | Architectural correctness; preserves the dependency graph. |
| `Renderer.tick(_:)` | `Renderer.tick(dt: Double, into commandBuffer: MTLCommandBuffer? = nil)`. | Headless CI tests need a no-encode path (`into: nil`); device tests / future passes pass a real buffer. |
| `registerPass(_ pass: RenderPass, after:)` | `registerPass<P: RenderPass>(_ pass: P, context: P.Context, after:)`. | `RenderPass.associatedtype Context` requires the context at registration for `AnyRenderPass` type-erased storage. |
| "first pass becomes `RenderPass.ID.root`" | `RenderPassId.root` is a fixed static ID; `ClearPass` registers with `.root`. | Static `.root` is simpler and matches the spec's `RenderPass.ID.root` notation. |

## Acceptance evidence (local M4 baselines)

| spec | item # | command | recorded | status |
|---|---|---|---|---|
| spec-001 | 2 | `XPETS_GPU_TESTS=1 swift test --filter RendererDeviceTests/testNoopPassDispatchP99UnderBudget` | (fill from local run) | pending |
| spec-001 | (encode order) | `XPETS_GPU_TESTS=1 swift test --filter RendererDeviceTests/testEncodeOrderMatchesRegisteredOrder` | pass | local green |
| spec-001 | (throw→drop) | `XPETS_GPU_TESTS=1 swift test --filter RendererDeviceTests/testThrowingPassDroppedAndLoopSurvives` | pass | local green |
```

- [ ] **Step 3: Record the no-op P99 value from the local run**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testNoopPassDispatchP99UnderBudget 2>&1 | tail -10`
Take the measured P99 (if the test prints it; if not, temporarily add `print("p99=\(p99)")` in the test, run, then remove the print). Edit `specs/Phase-2-Rendering/findings.md` evidence row: replace `(fill from local run)` / `pending` with the recorded ms value and `local green`.

- [ ] **Step 4: Set spec-001 Status → Done**

In `specs/Phase-2-Rendering/spec-001-metal-renderer.md`, change:
```
Status: Implementing
```
to:
```
Status: Done
```

- [ ] **Step 5: Run lint + full suite (final gate)**

Run: `./scripts/phase2-spec-lint.sh && swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: lint PASS; all tests green (Phase-1 30 + 8 logic + 3 device-skipped on CI = no failures).

- [ ] **Step 6: Commit**

```bash
git add api/renderer-api.md \
        specs/Phase-2-Rendering/findings.md \
        specs/Phase-2-Rendering/acceptance.md \
        specs/Phase-2-Rendering/spec-001-metal-renderer.md
git commit -m "docs(phase-2/spec-001): renderer-api + findings + Done

api/renderer-api.md (order, threading, retain-cycle); findings.md drift
log (drawClear/recordCounter/tick/registerPass); spec-001 Status: Done.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (run by plan author)

**1. Spec coverage (spec-001 §2 Deliverables → tasks):**
- `Renderer.registerPass/unregisterPass/currentFrameIndex` → Task 3 / 2.
- `RenderPass` protocol + `associatedtype Context` + `encode(into:context:)` + `gpuLabel` → Task 3.
- `MTLDevice` lifetime single (no second `MTLCreateSystemDefaultDevice`) → Application already creates one device; `Renderer.attach` uses the passed device. (Acceptance row 6 `MTLDevice count == 1` — not yet asserted by a test; **gap**: add a test? The existing Phase-1 code calls `MTLCreateSystemDefaultDevice()` once in `Application.run`. spec-001 acceptance row 6 "gpuCount fixture" — this is hard to unit-test without process-level device counting. Left as local-observed invariant; noted as accepted gap, not CI-gated.) 
- Pass execution order stable; throw → drop → continue → Task 9 (device test).
- Profiler `Counter` per pass → Task 8 (headless via sink) + Task 10 (wired in app).
- `RendererError.alreadyRunning` / `duplicatePassID` → Task 5 / 4.
- Tests TDD → every task is red→green.
- `api/renderer-api.md` → Task 11.
- spec-001 §5 Acceptance rows 1–8 (Performance/Enumerable/Assertable/Regression): row 1 (tick CPU ≤4ms) — not explicitly tested (local baseline territory; the P99 test covers dispatch cost); rows 3–8 → Tasks 3/4/5/6/7/8. Regression rows → Task 10/11 full-suite.

**2. Placeholder scan:** No TBD/TODO in plan steps. Task 11 Step 3 has "(fill from local run)" — that is an instruction to fill from a real measurement, not a plan placeholder; acceptable.

**3. Type consistency:** `RenderPassId` (not `RenderPass.ID`) used consistently — note the spec writes `RenderPass.ID` but code uses `RenderPassId` (Swift convention; logged in findings). `tick(dt:into:)` signature consistent across Tasks 3/6/7/8/9/10. `counterSink: ((String, Double) -> Void)?` consistent across Tasks 2/8/10. `registerPass(_:context:after:)` consistent across Tasks 3/4/5/8/10. `RendererError` cases consistent across Tasks 3/4/5.

**Accepted gap:** spec-001 acceptance row 6 (`MTLDevice` in-process count == 1 via `gpuCount` fixture) is not unit-testable without invasive process-level device counting; left as a locally-observed invariant (the codebase calls `MTLCreateSystemDefaultDevice()` exactly once, in `Application.run`). Documented here, not CI-gated.
