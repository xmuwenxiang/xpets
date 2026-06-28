import XCTest
@testable import DPProfiler

final class ProfilerTests: XCTestCase {
    func testSamplingPolicy_everyNFramesGatesOnFrameIndex() {
        XCTAssertTrue(SamplingPolicy.everyNFrames(2).shouldSampleThisFrame(0))
        XCTAssertFalse(SamplingPolicy.everyNFrames(2).shouldSampleThisFrame(1))
        XCTAssertTrue(SamplingPolicy.everyNFrames(2).shouldSampleThisFrame(2))
    }

    func testProfiler_rollingWindowCap() {
        let profiler = Profiler(windowSize: 5)
        for i in 0..<10 {
            profiler.tick(dt: 1.0/60, gpuMs: 0, cpuMs: 0, currentFramebufferDrop: 0)
            XCTAssertLessThanOrEqual(profiler.frameStats.count, 5)
        }
    }

    func testProfiler_offPolicy_noAllocs() {
        let profiler = Profiler(windowSize: 100)
        profiler.samplingPolicy = .off
        for _ in 0..<60 {
            profiler.tick(dt: 1.0/60, gpuMs: 0, cpuMs: 0, currentFramebufferDrop: 0)
        }
        XCTAssertEqual(profiler.frameStats.count, 0)
    }

    func testProfiler_counterAccumulates() {
        let profiler = Profiler(windowSize: 10)
        profiler.record(Counter(name: "drawCalls", value: 1))
        profiler.record(Counter(name: "drawCalls", value: 1))
        XCTAssertEqual(profiler.counters["drawCalls"]?.value, 2)
    }
}
