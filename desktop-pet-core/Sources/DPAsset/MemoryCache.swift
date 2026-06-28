import Foundation
import DPFoundation
import CryptoKit

/// Memory cache used by SPEC-004. Phase 1 ships a small LRU keyed by `(content-hash, type)`.
///
/// Capacity is in bytes; entries' `estimatedBytes` is reported by the decoder.
/// Concurrent hash-map lookups are guarded by a single dispatch queue — post Phase 1
/// is welcome to split shards; not worth it for the 32 MB budget.
public final class MemoryCache: @unchecked Sendable {
    public struct Entry {
        public let key: String
        public let value: Any
        public let estimatedBytes: Int
        public var lastAccess: TimeInterval
    }

    private let queue = DispatchQueue(label: "DPAsset.MemoryCache", attributes: .concurrent)
    private var entries: [String: Entry] = [:]
    /// LRU access order — position 0 is the most-recently-accessed key
    /// (front = head = MRU). The eviction policy drains the **tail** (LRU
    /// end) when capacity is exceeded.
    private var accessOrder: [String] = []
    public var capacity: Int
    private(set) var currentBytes: Int = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "MemoryCache capacity must be positive")
        self.capacity = capacity
    }

    /// Fetch a value. Returns nil if absent.
    public func get<T>(_ key: String) -> T? {
        queue.sync(flags: .barrier) {
            guard let entry = entries[key] else { return nil }
            accessOrder.removeAll { $0 == key }
            accessOrder.insert(key, at: 0)            // MRU at head
            entries[key] = Entry(key: entry.key, value: entry.value, estimatedBytes: entry.estimatedBytes, lastAccess: CFAbsoluteTimeGetCurrent())
            return entry.value as? T
        }
    }

    /// Insert or replace. If the new entry pushes us over capacity, evict LRU.
    public func set<T>(_ key: String, value: T, estimatedBytes: Int) {
        queue.sync(flags: .barrier) {
            if let existing = entries[key] {
                currentBytes -= existing.estimatedBytes
                accessOrder.removeAll { $0 == key }
            }
            accessOrder.insert(key, at: 0)            // MRU at head
            entries[key] = Entry(key: key, value: value, estimatedBytes: estimatedBytes, lastAccess: CFAbsoluteTimeGetCurrent())
            currentBytes += estimatedBytes
            self.evictIfNeeded()
        }
    }

    public func remove(_ key: String) {
        queue.sync(flags: .barrier) {
            if let entry = entries.removeValue(forKey: key) {
                currentBytes -= entry.estimatedBytes
                accessOrder.removeAll { $0 == key }
            }
        }
    }

    public func clear() {
        queue.sync(flags: .barrier) {
            entries.removeAll()
            accessOrder.removeAll()
            currentBytes = 0
        }
    }

    private func evictIfNeeded() {
        guard capacity > 0 else { return }
        // Drain from the tail — the Least Recently Used end of `accessOrder`.
        while currentBytes > capacity, !accessOrder.isEmpty, let oldest = accessOrder.last {
            if let entry = entries.removeValue(forKey: oldest) {
                currentBytes -= entry.estimatedBytes
            }
            accessOrder.removeLast()
        }
    }

    /// LRU-order keys — exposed for tests only.
    public func keysInLRUOrder() -> [String] {
        queue.sync { accessOrder }
    }
}

/// Helper to build a stable key combining content hash and asset type.
public enum AssetKeyBuilder {
    public static func sha256(of url: URL) throws -> AssetKey {
        let data = try Data(contentsOf: url)
        return AssetKey(hash: sha256(data))
    }

    public static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Cache key combining content hash and asset type, so the LRU slot reflects
    /// "this content, fetched as this kind".
    public static func cacheKey(for assetKey: AssetKey, type: AssetType) -> String {
        return "\(assetKey.hash)-\(type.rawValue)"
    }
}
