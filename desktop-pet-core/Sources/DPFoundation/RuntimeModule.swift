import Foundation

/// `RuntimeContext` — the boot-time context handed to every `RuntimeModule`.
/// It carries resolved config and the shared logger. Phase 4+ adds the asset-pointer
/// registry once async asset load lands; Phase 6+ adds scene reference.
public struct RuntimeContext: Sendable {
    public let config: DesktopPetConfig
    public let logger: Logger

    public init(config: DesktopPetConfig, logger: Logger) {
        self.config = config
        self.logger = logger
    }
}

/// Boot phase every module goes through. Sequencing is enforced by
/// `ModuleManager` (SPEC-003).
public enum BootPhase: Int, Comparable {
    case willBoot  = 0
    case didBoot   = 1
    case willTick  = 2   // rare: per-frame pre-work
    case didTick   = 3
    case willShut  = 4

    public static func < (lhs: BootPhase, rhs: BootPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Single-protocol that `ModuleManager` uses to register and tick Phase 1 modules.
/// Each Work Spec exposes at least one mock impl to keep tests hermetic.
public protocol RuntimeModule: AnyObject {
    /// Stable name used for dependency resolution and log context.
    var name: String { get }

    /// Names of modules this module depends on. Boot fails fast if any are missing
    /// (acceptance: spec-003 §5).
    var dependencies: [String] { get }

    /// Each method throws so a misbehaving module can surface the error to `ModuleManager`.
    /// In the default implementation `ModuleManager.bootAll` / `tickAll` / `shutdownAll`
    /// catch and degrade the offender (per acceptance: spec-003 §5 row "Throwing module
    /// does not halt UpdateLoop").
    func moduleWillBoot(_ ctx: RuntimeContext) throws
    func moduleDidBoot(_ ctx: RuntimeContext) throws
    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) throws
    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) throws
    func moduleWillShutdown(_ ctx: RuntimeContext) throws

    /// Throwing here must NOT halt the Update Loop. `ModuleManager` catches and
    /// marks the module `.degraded`; future ticks skip until a recovery signal lands.
    func moduleDidThrow(_ error: Error, phase: BootPhase, ctx: RuntimeContext)
}

extension RuntimeModule {
    public var dependencies: [String] { [] }
    public func moduleDidThrow(_ error: Error, phase: BootPhase, ctx: RuntimeContext) {
        ctx.logger.warn("module \(name) error in \(phase): \(error)")
    }
}

/// State machine the manager tracks per module.
public enum ModuleState: Equatable, Sendable {
    case registered
    case running
    case degraded(reason: String)
    case shutDown
}
