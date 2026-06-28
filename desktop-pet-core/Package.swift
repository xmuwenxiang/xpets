// swift-tools-version: 5.10
//
// desktop-pet-core — the engine package for the AI Native 3D Desktop Pet.
// See specs/Phase-1-Foundation/overview.md and spec-001-bootstrap.md.
//
import PackageDescription

let package = Package(
    name: "desktop-pet-core",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DPFoundation", targets: ["DPFoundation"]),
        .library(name: "DPRuntime",    targets: ["DPRuntime"]),
        .library(name: "DPWindow",     targets: ["DPWindow"]),
        .library(name: "DPRenderer",   targets: ["DPRenderer"]),
        .library(name: "DPAsset",      targets: ["DPAsset"]),
        .library(name: "DPAnimation", targets: ["DPAnimation"]),
        .library(name: "DPProfiler",   targets: ["DPProfiler"]),
        .executable(name: "desktop-pet", targets: ["DesktopPetApp"])
    ],
    dependencies: [
        // Phase 1 ships pure-Swift dependencies only. Comment shows where Phase N adds them.
        // .package(url: "https://github.com/<owner>/glTF-Swift.git", from: "0.4.0"), // SPEC-004
        // .package(url: "https://github.com/<owner>/Yams.git", from: "5.0.0"),      // SPEC-001 (YAML)
    ],
    targets: [
        // Foundation: Logger, Config, common types. Leaf module — no internal deps.
        .target(
            name: "DPFoundation",
            path: "Sources/DPFoundation"
        ),
        // Window: NSWindow wrapper. Depends on Foundation only.
        .target(
            name: "DPWindow",
            dependencies: ["DPFoundation"],
            path: "Sources/DPWindow"
        ),
        // Renderer: Metal entry, surface handoff. Phase 1 only boots a stub MTKView.
        .target(
            name: "DPRenderer",
            dependencies: ["DPFoundation", "DPWindow"],
            path: "Sources/DPRenderer"
        ),
        // Asset: GLB / KTX2 / Shader decoders. Phase 1 ships pure-Swift GLB parser (no third-party).
        .target(
            name: "DPAsset",
            dependencies: ["DPFoundation", "DPRenderer"],
            path: "Sources/DPAsset",
            resources: [
                .process("Resources")
            ]
        ),
        // Animation: Skeleton + Idle (catmull-rom interp), GPU skinning. Phase 1 single-clip only.
        .target(
            name: "DPAnimation",
            dependencies: ["DPFoundation", "DPAsset", "DPRenderer"],
            path: "Sources/DPAnimation"
        ),
        // Profiler: FrameStats / Memory / Aggregator. Depends on Foundation (and Renderer for GPU time).
        .target(
            name: "DPProfiler",
            dependencies: ["DPFoundation", "DPRenderer"],
            path: "Sources/DPProfiler"
        ),
        // Runtime: Application / Scene / UpdateLoop / ModuleManager. Top-level orchestrator.
        .target(
            name: "DPRuntime",
            dependencies: [
                "DPFoundation", "DPWindow", "DPRenderer",
                "DPAsset", "DPAnimation", "DPProfiler"
            ],
            path: "Sources/DPRuntime"
        ),

        // Executable demo: the Phase 1 "boot the app and observe" entry point. The full
        // .app bundle lives in Phase 9; this is the standalone `swift run .desktop-pet`
        // path used during development.
        .executableTarget(
            name: "DesktopPetApp",
            dependencies: ["DPRuntime", "DPFoundation"],
            path: "Sources/DesktopPetApp"
        ),

        // ---------- Tests ----------
        .testTarget(
            name: "DPFoundationTests",
            dependencies: ["DPFoundation"],
            path: "Tests/DPFoundationTests"
        ),
        .testTarget(
            name: "DPWindowTests",
            dependencies: ["DPWindow", "DPFoundation"],
            path: "Tests/DPWindowTests"
        ),
        .testTarget(
            name: "DPRuntimeTests",
            dependencies: ["DPRuntime", "DPFoundation"],
            path: "Tests/DPRuntimeTests"
        ),
        .testTarget(
            name: "DPAssetTests",
            dependencies: ["DPAsset", "DPFoundation"],
            path: "Tests/DPAssetTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "DPAnimationTests",
            dependencies: ["DPAnimation", "DPAsset", "DPFoundation"],
            path: "Tests/DPAnimationTests"
        ),
        .testTarget(
            name: "DPProfilerTests",
            dependencies: ["DPProfiler", "DPFoundation"],
            path: "Tests/DPProfilerTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
