import XCTest
@testable import DPRuntime
@testable import DPFoundation

final class ModuleManagerTests: XCTestCase {
    /// Spec-003 §5 (Assertable): ModuleManager rejects a module whose declared
    /// dependency is missing — fails fast at boot, not at first tick.
    func testRegister_missingDependencyThrows() {
        let manager = ModuleManager()
        let module = ThrowingModule(name: "Test", dependencies: ["Missing"])
        XCTAssertThrowsError(try manager.register(module))
    }

    func testDuplicateRegistrationThrows() {
        let manager = ModuleManager()
        XCTAssertNoThrow(try manager.register(SimpleModule(name: "A")))
        XCTAssertThrowsError(try manager.register(SimpleModule(name: "A")))
    }

    func testBootOrdersByDependency() throws {
        let manager = ModuleManager()
        XCTAssertNoThrow(try manager.register(ModuleB(name: "B")))
        XCTAssertNoThrow(try manager.register(ModuleA(name: "A", dependencies: ["B"])))
        let ctx = RuntimeContext(config: .default, logger: Logger(subsystem: "test", sinks: []))
        XCTAssertNoThrow(try manager.bootAll(ctx: ctx))
        // A depends on B, so B first.
        XCTAssertEqual(manager.ordering(), ["B", "A"])
    }

    func testThrowingModule_doesNotHaltLoop() throws {
        let manager = ModuleManager()
        let ctx = RuntimeContext(config: .default, logger: Logger(subsystem: "test", sinks: []))
        XCTAssertNoThrow(try manager.register(ThrowingModule(name: "Boom", dependencies: [])))
        XCTAssertNoThrow(try manager.register(SimpleModule(name: "Survivor")))
        XCTAssertNoThrow(try manager.bootAll(ctx: ctx))
        manager.tickAll(ctx: ctx, dt: 1/60)
        // Loop survives — we get here without throwing.
        XCTAssertEqual(manager.ordering().count, 2)
    }

    func testShutdownOrderIsReverseBootOrder() throws {
        let manager = ModuleManager()
        let ctx = RuntimeContext(config: .default, logger: Logger(subsystem: "test", sinks: []))
        XCTAssertNoThrow(try manager.register(ModuleB(name: "B")))
        XCTAssertNoThrow(try manager.register(ModuleA(name: "A", dependencies: ["B"])))
        try manager.bootAll(ctx: ctx)
        let shutdown = ShutdownCoordinator(moduleOrder: manager.ordering())
        XCTAssertTrue(shutdown.verifyReverse(bootOrder: ["B", "A"]))
    }
}

// Test helpers
final class SimpleModule: RuntimeModule {
    let name: String
    var dependencies: [String]
    init(name: String, dependencies: [String] = []) {
        self.name = name
        self.dependencies = dependencies
    }
    var didTickCount = 0
    var didShutCount = 0
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {}
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) { didTickCount += 1 }
    func moduleWillShutdown(_ ctx: RuntimeContext) { didShutCount += 1 }
}

/// `ThrowingModule` is the **non-fatal** counterpart: it raises a recoverable
/// `TestError.boom` at `moduleDidBoot` time. The Runtime catches the throw
/// (per spec-003 §5 row "Throwing module does not halt UpdateLoop") and
/// marks this module `.degraded`. Ponytail: the legacy variant used
/// `fatalError("boom")` which cannot be caught and is by design outside
/// the Runtime's resilience guarantee.
final class ThrowingModule: RuntimeModule {
    struct TestError: Error { let code: String }
    let name: String
    let dependencies: [String]
    init(name: String, dependencies: [String]) {
        self.name = name
        self.dependencies = dependencies
    }
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) throws {
        throw TestError(code: "boom")
    }
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}

final class ModuleA: RuntimeModule {
    let name: String
    let dependencies: [String]
    init(name: String, dependencies: [String]) { self.name = name; self.dependencies = dependencies }
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {}
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}

final class ModuleB: RuntimeModule {
    let name: String
    init(name: String) { self.name = name }
    func moduleWillBoot(_ ctx: RuntimeContext) {}
    func moduleDidBoot(_ ctx: RuntimeContext) {}
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {}
    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}
