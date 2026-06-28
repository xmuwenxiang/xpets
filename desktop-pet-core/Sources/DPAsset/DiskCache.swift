import Foundation
import DPFoundation

/// DiskCache — the Phase 1 contract, not the implementation. spec-004 §2 explicitly
/// says Phase 1 ships the interface only; full disk cache lands in Phase 8.
///
/// Phase 1 uses this in tests as a no-op; production falls through to MemoryCache.
public protocol DiskCache: Sendable {
    /// Storage locale.
    var rootURL: URL { get }
    /// Read previously-persisted data for `key`. Implementations may return nil
    /// even on cache hit if the persisted entry is corrupt or expired.
    func read(_ key: AssetKey) throws -> Data?
    /// Persist `data` for `key`.
    func write(_ data: Data, key: AssetKey) throws
    /// Invalidate the cache.
    func invalidateAll() throws
}

/// Default disk cache path; computed but not used in Phase 1.
public enum StandardCacheLocation {
    public static var cachesURL: URL {
        let base = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Caches")
        return base.appendingPathComponent("DesktopPet/decoded", isDirectory: true)
    }
}
