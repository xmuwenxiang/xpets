import Foundation

/// Metal shader source for spec-002b (unlit textured). Compiled at runtime via
/// `MTLDevice.makeLibrary(source:options:)` — no .metal files (SwiftPM doesn't
/// compile them; this keeps `swift test`/CI intact). 2c swaps the fragment for
/// PBR Cook-Torrance.
public enum Shaders {
    public static let vertexSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

struct Uniforms {
    float4x4 mvp;
};

vertex VertexOut fox_vertex(VertexIn in [[stage_in]],
                            constant Uniforms& uni [[buffer(2)]]) {
    VertexOut out;
    out.position = uni.mvp * float4(in.position, 1.0);
    // Flip V to compensate for CGContext's bottom-left origin (PNGDecoder).
    out.texcoord = float2(in.texcoord.x, 1.0 - in.texcoord.y);
    return out;
}
"""

    public static let fragmentSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

fragment float4 fox_fragment(VertexOut in [[stage_in]],
                            texture2d<float> albedo [[texture(0)]],
                            sampler albedoSampler [[sampler(0)]]) {
    return albedo.sample(albedoSampler, in.texcoord);
}
"""
}
