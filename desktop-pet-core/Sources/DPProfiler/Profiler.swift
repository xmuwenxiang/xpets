import Foundation
import DPFoundation
import DPRenderer
import Darwin

/// Per-frame stats. Codable so debug dumps round-trip.
public struct FrameStats: Codable, Sendable, Equatable {
    public var dt: Double
    public var gpuMs: Double
    public var cpuMs: Double
    public var droppedFrames: Int

    public init(dt: Double = 0, gpuMs: Double = 0, cpuMs: Double = 0, droppedFrames: Int = 0) {
        self.dt = dt
        self.gpuMs = gpuMs
        self.cpuMs = cpuMs
        self.droppedFrames = droppedFrames
    }
}

/// One memory snapshot. Uses Mach's task_info for resident + footprint.
public struct MemorySample: Codable, Sendable, Equatable {
    public var residentMB: Double
    public var footprintMB: Double

    public init(residentMB: Double = 0, footprintMB: Double = 0) {
        self.residentMB = residentMB
        self.footprintMB = footprintMB
    }
}

/// Ad-hoc counters for ad-hoc capture (Phase 2 may use this for draw-call counts).
public struct Counter: Sendable, Codable, Equatable {
    public let name: String
    public var value: Double
    public init(name: String, value: Double) {
        self.name = name
        self.value = value
    }
}

/// Sampling policy — gated by config to keep the default path zero-overhead.
public enum SamplingPolicy: Sendable, Equatable {
    case off
    case everyFrame
    case everyNFrames(Int)
    case manual
}

public extension SamplingPolicy {
    func shouldSampleThisFrame(_ frameIndex: Int) -> Bool {
        switch self {
        case .off: return false
        case .everyFrame: return true
        case .everyNFrames(let n): return n > 0 ? (frameIndex % n == 0) : true
        case .manual: return false
        }
    }
}

/// Centralized profiler. SPEC-006 acceptance gates:
/// - ≤0.5 ms/frame (`.everyFrame`)
/// - 0 allocations/frame (`.off`)
public final class Profiler: @unchecked Sendable {
    public static let shared = Profiler()

    public private(set) var frameStats: [FrameStats]
    public private(set) var memorySamples: [MemorySample]
    public private(set) var counters: [String: Counter] = [:]

    /// Rolling window cap — acceptance criterion: rolling window cap = 600.
    public let windowSize: Int

    public var samplingPolicy: SamplingPolicy = .everyNFrames(60)

    /// Per-frame emitter: called every frame regardless of policy (the gating is inside
    /// on `tick`). Tests can swap this in.
    public var frameEmitter: ((FrameStats) -> Void)?
    public var memoryEmitter: ((MemorySample) -> Void)?

    private var frameIndex: Int = 0
    private let lock = NSLock()

    public init(windowSize: Int = 600) {
        precondition(windowSize > 0)
        self.windowSize = windowSize
        self.frameStats = []
        self.memorySamples = []
        self.frameStats.reserveCapacity(windowSize)
        self.memorySamples.reserveCapacity(windowSize)
    }

    /// Stay-public so tests can flip into benchmark mode.
    public func enableForBenchmark() {
        samplingPolicy = .everyFrame
    }

    /// Phase 6+: extension point; Phase 1 ships the stub.
    public func record(_ counter: Counter) {
        lock.lock()
        defer { lock.unlock() }
        if var existing = counters[counter.name] {
            existing.value += counter.value
            self.counters[counter.name] = existing
        } else {
            self.counters[counter.name] = counter
        }
    }

    /// Called by the UpdateLoop each frame with the measured dt & gpuMs.
    public func tick(dt: Double, gpuMs: Double, cpuMs: Double, currentFramebufferDrop: Int) {
        // Increment the per-frame counter *before* the policy check so frameIndex
        // is monotonically increasing whether or not the policy gates sampling this
        // tick (e.g. .off / .manual). This keeps the memory-sample cadence aligned
        // with frame cadence rather than sample-cadence (the previous off-by-one
        // gated against `memorySamples.count` which only grows on sample ticks).
        let absoluteFrame = frameIndex
        frameIndex += 1

        guard samplingPolicy.shouldSampleThisFrame(absoluteFrame) else {
            return
        }
        let stats = FrameStats(dt: dt, gpuMs: gpuMs, cpuMs: cpuMs, droppedFrames: currentFramebufferDrop)
        lock.lock()
        if frameStats.count >= windowSize { frameStats.removeFirst() }
        frameStats.append(stats)
        lock.unlock()
        frameEmitter?(stats)

        // Polled but non-blocking memory sample — uses a background queue to avoid
        // blocking tick. Sampled every 60 frames regardless of policy mode so
        // Phase-9 telemetry (Phase 1 not yet) has a stable cadence.
        if absoluteFrame % 60 == 0 {
            memorySamplesQueue.async { [weak self] in
                guard let self = self else { return }
                let sample = MachTaskMemoryProbe.read()
                self.lock.lock()
                defer { self.lock.unlock() }
                if self.memorySamples.count >= self.windowSize { self.memorySamples.removeFirst() }
                self.memorySamples.append(sample)
                self.memoryEmitter?(sample)
            }
        }
    }

    /// Sample memory on-demand. Used by asset-load completion handlers so SPEC-004's
    /// acceptance ("memory delta reported within ±0.5 MB") can land.
    public func sampleMemoryNow() -> MemorySample {
        let sample = MachTaskMemoryProbe.read()
        lock.lock()
        defer { lock.unlock() }
        memorySamples.append(sample)
        return sample
    }

    public func lastFPSWindow() -> Double {
        lock.lock()
        defer { lock.unlock() }
        guard !frameStats.isEmpty else { return 0 }
        let total = frameStats.reduce(0.0) { $0 + $1.dt }
        guard total > 0 else { return 0 }
        return Double(frameStats.count) / total
    }

    public func percentile(_ p: Double) -> Double? {
        lock.lock()
        var stats = frameStats
        lock.unlock()
        guard !stats.isEmpty else { return nil }
        stats.sort { $0.dt < $1.dt }
        let clamped = max(0, min(1, p))
        let idx = Int(Double(stats.count - 1) * clamped)
        return stats[idx].dt * 1000
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        frameStats.removeAll()
        memorySamples.removeAll()
        counters.removeAll()
        frameIndex = 0
    }
}

/// Memory probe via `task_info(mach_task_self(), TASK_VM_INFO, ...)`.
public enum MachTaskMemoryProbe {
    public static func read() -> MemorySample {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return MemorySample() }
        let resident = Double(info.resident_size) / (1024 * 1024)
        let footprint = Double(info.phys_footprint) / (1024 * 1024)
        return MemorySample(residentMB: resident, footprintMB: footprint)
    }
}

private let memorySamplesQueue = DispatchQueue(label: "DPProfiler.MemoryProbe", qos: .background)

/// Mock returning deterministic memory samples — used by tests so Mach isn't required.
public final class ProfilerMock {
    public init() {}
    public func read() -> MemorySample {
        MemorySample(residentMB: 24.0, footprintMB: 80.0)
    }
}
