import Foundation
import DPFoundation

/// Phase 1 Asset loader. Public API is `load(url:type:)` (SPEC-004 §2).
public final class AssetLoader: @unchecked Sendable {
    public let cache: MemoryCache
    private let logger: Logger

    /// In-flight decodes keyed by `key+type`. Used for single-flight semantics: 50
    /// concurrent loads of the same URL yield one decode (acceptance criterion).
    /// Ponytail: mutated under `inflightSerializer` (an async-safe DispatchQueue)
    /// rather than NSLock — Swift 6 strict concurrency deprecates NSLock in async contexts.
    private var inflight: [String: Task<Asset, Error>] = [:]
    private let inflightSerializer = DispatchQueue(label: "DPAsset.Loader.inflight", qos: .userInitiated)

    public init(cache: MemoryCache, logger: Logger = .shared) {
        precondition(cache.capacity > 0)
        self.cache = cache
        self.logger = logger
    }

    /// Load any asset. Hits the cache first (single-flight for concurrent calls).
    /// Ponytail: NSLock in async contexts is a Swift 6 warning. We rely on the
    /// serial `inflightSerializer` DispatchQueue — its `.sync` is fine in both
    /// sync *and* async contexts because the closure body never suspends before
    /// the queue is released (no `await` points, no `Task.detached` creation
    /// inside the closure — task creation happens *after* `.sync` returns).
    public func load(_ url: URL, type: AssetType) async throws -> Asset {
        let assetKey: AssetKey
        do {
            assetKey = try AssetKeyBuilder.sha256(of: url)
        } catch {
            throw AssetError.ioError(underlying: "\(error)")
        }
        let cacheKey = AssetKeyBuilder.cacheKey(for: assetKey, type: type)

        // 1) Cache hit (typed)
        if let cached: Asset = cache.get(cacheKey) {
            logger.debug("asset cache hit url=\(url.lastPathComponent) type=\(type.rawValue)")
            return cached
        }

        // 2) Single-flight join. The dispatch `.sync` here does not suspend
        // (no `await` inside the closure), so it is safe from within `async`.
        let task: Task<Asset, Error> = inflightSerializer.sync {
            if let existing = inflight[cacheKey] {
                return existing
            }
            let work = Task<Asset, Error>.detached(priority: .userInitiated) { [self] in
                try await decode(url: url, type: type, key: assetKey)
            }
            inflight[cacheKey] = work
            return work
        }

        let asset = try await task.value

        // Once the work completes, clear the inflight entry so future loads can
        // get a fresh decode. Done outside any sync call to avoid re-entrancy.
        _ = inflightSerializer.sync {
            self.inflight.removeValue(forKey: cacheKey)
        }

        let size = EstimateSize.estimate(asset: asset)
        cache.set(cacheKey, value: asset, estimatedBytes: size)
        return asset
    }

    // MARK: - Decoder dispatch
    private func decode(url: URL, type: AssetType, key: AssetKey) async throws -> Asset {
        switch type {
        case .glb: return .glb(try GLBDecoder.decode(url: url))
        case .ktx2: return .ktx2(try KTX2Decoder.decode(url: url))
        case .shader: return .shader(try ShaderDecoder.decode(url: url))
        }
    }
}

enum EstimateSize {
    static func estimate(asset: Asset) -> Int {
        switch asset {
        case .glb(let glb):
            return glb.skeleton.bones.count * MemoryLayout<Float4x4>.size
                 + glb.mesh.vertexCount * MemoryLayout<SIMD4<UInt16>>.stride * 2
        case .ktx2: return 4096
        case .shader(let shader):
            return (shader.sourceHash.utf8.count + 1) * 4
        case .unsupported: return 0
        }
    }
}
