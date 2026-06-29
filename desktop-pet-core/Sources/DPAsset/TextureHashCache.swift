import Foundation

public enum TextureCacheResult: Sendable, Equatable {
    case hit
    case miss
}

/// Process-level texture cache keyed on a composite assetKey (e.g.
/// "<assetHash>.<materialIndex>.<channel>"). Phase 2a records hit/miss for the
/// albedo channel at `Material.fromGlb` time; MTLTexture caching lands in 2b.
public final class TextureHashCache: @unchecked Sendable {
    public static let shared = TextureHashCache()
    private var store: Set<String> = []
    private let lock = NSLock()

    public init() {}

    public func lookup(assetKey: String) -> TextureCacheResult {
        lock.lock(); defer { lock.unlock() }
        return store.contains(assetKey) ? .hit : .miss
    }

    public func store(assetKey: String) {
        lock.lock(); defer { lock.unlock() }
        store.insert(assetKey)
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        store.removeAll()
    }
}