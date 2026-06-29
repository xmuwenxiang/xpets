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

    private func makeEncoder(device: MTLDevice, queue: MTLCommandQueue, size: (Int, Int) = (64, 64)) -> (MTLCommandBuffer, MTLRenderCommandEncoder) {
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size.0, height: size.1, mipmapped: false)
        texDesc.usage = [.renderTarget]
        let tex = device.makeTexture(descriptor: texDesc)!
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = tex
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        let buffer = queue.makeCommandBuffer()!
        let enc = buffer.makeRenderCommandEncoder(descriptor: rpd)!
        return (buffer, enc)
    }

    /// Encode order matches registered order. A TestPass appends its id to a
    /// shared recorder when encode is invoked.
    func testEncodeOrderMatchesRegisteredOrder() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            try XCTSkip("no Metal device"); return
        }
        final class RecordingPass: RenderPass {
            typealias Context = Recorder
            let id: RenderPassId
            var gpuLabel: String { "rec.\(id.raw)" }
            private let recorder: Recorder
            init(_ raw: String, recorder: Recorder) { self.id = RenderPassId(raw); self.recorder = recorder }
            func encode(into encoder: MTLRenderCommandEncoder, context: Recorder) throws -> RenderPassId {
                context.order.append(id); return id
            }
        }
        final class Recorder { var order: [RenderPassId] = [] }
        let recorder = Recorder()
        let r = Renderer(device: device)
        try r.registerPass(RecordingPass("A", recorder: recorder), context: recorder)
        try r.registerPass(RecordingPass("B", recorder: recorder), context: recorder)
        try r.registerPass(RecordingPass("C", recorder: recorder), context: recorder)
        let (buffer, enc) = makeEncoder(device: device, queue: queue)
        r.tick(dt: 1.0 / 60.0, into: enc)
        enc.endEncoding()
        buffer.commit()
        XCTAssertEqual(recorder.order, [RenderPassId("A"), RenderPassId("B"), RenderPassId("C")])
    }

    /// A pass that throws inside encode is dropped after the frame; the Renderer
    /// keeps ticking (Loop-survives invariant).
    func testThrowingPassDroppedAndLoopSurvives() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            try XCTSkip("no Metal device"); return
        }
        enum Boom: Error { case boom }
        final class ThrowingPass: RenderPass {
            typealias Context = Void
            let id = RenderPassId("boom")
            var gpuLabel: String { "boom" }
            func encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId { throw Boom.boom }
        }
        final class OKPass: RenderPass {
            typealias Context = Void
            let id = RenderPassId("ok")
            var gpuLabel: String { "ok" }
            func encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId { id }
        }
        let r = Renderer(device: device)
        try r.registerPass(ThrowingPass(), context: ())
        try r.registerPass(OKPass(), context: ())
        // Frame 1: boom throws → dropped after frame; ok survives.
        let (b1, enc1) = makeEncoder(device: device, queue: queue)
        r.tick(dt: 1.0 / 60.0, into: enc1)
        enc1.endEncoding()
        b1.commit()
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("ok")])
        // Frame 2: loop survives, ok still ticks.
        let (b2, enc2) = makeEncoder(device: device, queue: queue)
        r.tick(dt: 1.0 / 60.0, into: enc2)
        enc2.endEncoding()
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
            try XCTSkip("no Metal device"); return
        }
        final class NoopPass: RenderPass {
            typealias Context = Void
            let id = RenderPassId("noop")
            var gpuLabel: String { "noop" }
            func encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId { id }
        }
        let r = Renderer(device: device)
        try r.registerPass(NoopPass(), context: ())
        var samples: [Double] = []
        samples.reserveCapacity(600)
        for _ in 0..<600 {
            let (buffer, enc) = makeEncoder(device: device, queue: queue)
            let start = CFAbsoluteTimeGetCurrent()
            r.tick(dt: 1.0 / 60.0, into: enc)
            enc.endEncoding()
            buffer.commit()
            samples.append((CFAbsoluteTimeGetCurrent() - start) * 1000.0)
        }
        samples.sort()
        let p99 = samples[Int(Double(samples.count - 1) * 0.99)]
        // Print for the evidence record (Task 11 captures this value).
        print("XPETS no-op dispatch P99 = \(p99) ms")
        XCTAssertLessThanOrEqual(p99, 0.5, "no-op dispatch P99 \(p99)ms exceeds 0.5ms budget")
    }
}