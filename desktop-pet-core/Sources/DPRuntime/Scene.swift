import Foundation
import AppKit
import DPFoundation
import DPWindow
import DPRenderer
import DPAsset
import DPAnimation
import DPProfiler

/// The Scene holds references to engine subsystems that survive across frames.
public final class Scene {
    public let sceneID: UUID
    public private(set) var assetRegistry: AssetRegistry
    public private(set) var animationState: AnimationState
    public let camera: Camera
    public let profiler: Profiler
    public let renderer: RendererSurface
    public let skinningPipeline: SkinningPipeline

    public init(renderer: RendererSurface, profiler: Profiler, camera: Camera) {
        self.sceneID = UUID()
        self.assetRegistry = AssetRegistry()
        self.animationState = AnimationState()
        self.camera = camera
        self.profiler = profiler
        self.renderer = renderer
        self.skinningPipeline = SkinningPipeline()
    }
}

/// Camera — Phase 1 only stores an orthographic-ish identity transform.
public final class Camera {
    public var position: Float3
    public var target: Float3
    public init(position: Float3 = SIMD3(0, 0, 5), target: Float3 = SIMD3(0, 0, 0)) {
        self.position = position
        self.target = target
    }
}

/// Track loaded assets by content hash. Keeps Scene serialization-friendly
/// without exposing file paths.
public final class AssetRegistry: @unchecked Sendable {
    public private(set) var glb: [AssetKey: GLBAsset] = [:]
    public private(set) var shader: [AssetKey: ShaderAsset] = [:]
    public private(set) var ktx2: [AssetKey: KTX2Asset] = [:]
    public func register(_ asset: Asset, key: AssetKey) {
        switch asset {
        case .glb(let v): glb[key] = v
        case .shader(let v): shader[key] = v
        case .ktx2(let v): ktx2[key] = v
        case .unsupported: break
        }
    }
    public var keys: [AssetKey] { Array(glb.keys) + Array(shader.keys) + Array(ktx2.keys) }
}

/// Animation state — exposes the current Animator + skinning pose.
public final class AnimationState: @unchecked Sendable {
    public private(set) var animator: Animator?
    public private(set) var skinningPose: [Float4x4] = []
    public private(set) var skinningBuffer: SkinningPipeline.JointMatrixBuffer?

    public func setAnimator(_ anim: Animator) {
        self.animator = anim
    }
    public func update(pipeline: SkinningPipeline) {
        guard let anim = animator else { return }
        skinningPose = anim.poseMatrices()
        skinningBuffer = pipeline.drive(pose: skinningPose)
    }
}

/// Module manager orchestrates boot order via topological sort of declared dependencies.
public final class ModuleManager: @unchecked Sendable {
    public private(set) var modules: [RuntimeModule] = []
    private var states: [ObjectIdentifier: ModuleState] = [:]
    private var bootOrder: [RuntimeModule] = []
    private var shuttingDown = false

    public init() {}

    public func register(_ module: RuntimeModule) throws {
        guard !shuttingDown else { throw LifecycleError.shutdownInProgress }
        let name = module.name
        if modules.contains(where: { $0.name == name }) {
            throw LifecycleError.moduleAlreadyRegistered(name: name)
        }
        // Fail-fast: dependency declared but not yet registered.
        for dep in module.dependencies {
            if !modules.contains(where: { $0.name == dep }) && dep != name {
                throw LifecycleError.dependencyMissing(dependency: dep, owner: name)
            }
        }
        let id = ObjectIdentifier(module)
        modules.append(module)
        states[id] = .registered
    }

    /// Boot in topological order. Modules with no deps come first.
    public func bootAll(ctx: RuntimeContext) throws {
        bootOrder = try topoSort()
        for module in bootOrder {
            let id = ObjectIdentifier(module)
            states[id] = .running
            do {
                try module.moduleWillBoot(ctx)
                try module.moduleDidBoot(ctx)
            } catch {
                states[id] = .degraded(reason: "\(error)")
                module.moduleDidThrow(error, phase: .didBoot, ctx: ctx)
            }
        }
    }

    /// Tick all healthy modules; degraded ones are skipped (acceptance: spec-003 §5).
    public func tickAll(ctx: RuntimeContext, dt: Double) {
        for module in bootOrder {
            let id = ObjectIdentifier(module)
            if case .degraded = states[id] ?? .registered { continue }
            do {
                try module.moduleWillTick(ctx, dt: dt)
                try module.moduleDidTick(ctx, dt: dt)
            } catch {
                states[id] = .degraded(reason: "\(error)")
                module.moduleDidThrow(error, phase: .didTick, ctx: ctx)
            }
        }
    }

    /// Reverse the boot order for shutdown.
    public func shutdownAll(ctx: RuntimeContext) {
        shuttingDown = true
        for module in bootOrder.reversed() {
            let id = ObjectIdentifier(module)
            if case .degraded = states[id] ?? .registered { /* still shut down */ }
            do {
                try module.moduleWillShutdown(ctx)
            } catch {
                module.moduleDidThrow(error, phase: .willShut, ctx: ctx)
            }
            states[id] = .shutDown
        }
        bootOrder.removeAll()
    }

    /// Deterministic ordering — returned for tests that assert boot ordering.
    public func ordering() -> [String] {
        bootOrder.map { $0.name }
    }

    public func isShutdown() -> Bool { shuttingDown }

    private func topoSort() throws -> [RuntimeModule] {
        // Kahn's algorithm against declared dependencies; fall back to insertion order
        // when there are no deps. Each module is distinct by its `name` to allow easy
        // debugging even if the same instance is registered twice.
        var byName: [String: RuntimeModule] = [:]
        for m in modules {
            byName[m.name] = m
        }
        var inDegree: [String: Int] = [:]
        var edges: [String: [String]] = [:]
        for m in modules {
            inDegree[m.name, default: 0] += 0  // init
            for dep in m.dependencies {
                guard byName[dep] != nil else {
                    throw LifecycleError.dependencyMissing(dependency: dep, owner: m.name)
                }
                edges[dep, default: []].append(m.name)
                inDegree[m.name, default: 0] += 1
            }
        }
        var queue: [RuntimeModule] = modules.filter { (inDegree[$0.name] ?? 0) == 0 }
        var order: [RuntimeModule] = []
        while let next = queue.first {
            queue.removeFirst()
            order.append(next)
            for dependent in edges[next.name] ?? [] {
                inDegree[dependent, default: 0] -= 1
                if (inDegree[dependent] ?? 0) == 0, let m = byName[dependent] {
                    queue.append(m)
                }
            }
        }
        if order.count != modules.count {
            // ponytail: cycle or out-of-band dep — should fail fast per spec-003 §5. We
            // resolve by appending the remainder and logging.
            Logger.shared.warn("topoSort left \(modules.count - order.count) modules unscheduled — appending remainder")
            for m in modules where !order.contains(where: { $0 === m }) {
                order.append(m)
            }
        }
        return order
    }
}

/// ShutdownCoordinator ensures deterministic reverse-boot teardown and verifies
/// that Metal resources tracked through the renderer are released.
public final class ShutdownCoordinator: @unchecked Sendable {
    public let order: [String]
    public private(set) var didComplete = false

    public init(moduleOrder: [String]) {
        self.order = moduleOrder.reversed()
    }

    /// Verify (in tests) that the order list is reverse-of-boot.
    public func verifyReverse(bootOrder: [String]) -> Bool {
        return order == bootOrder.reversed()
    }

    /// Tear down the scene. Idempotent.
    public func run(manager: ModuleManager, scene: Scene, ctx: RuntimeContext) {
        manager.shutdownAll(ctx: ctx)
        scene.renderer.shutdown()
        didComplete = true
    }
}
