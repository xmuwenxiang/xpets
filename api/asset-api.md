# DPAsset API

> Module: `DPAsset` · Owner Phase: 1 (memory loader); Phase 9 (full disk-cache)
> Related: `specs/Phase-1-Foundation/spec-004-asset.md`

---

## Public Surface

```
public enum AssetLoadError: Error {
    case ioError(underlying: Error)
    case decodeError(reason: String)
    case schemaMismatch(field: String)
    case unsupportedVersion
}

public protocol AssetLoader {
    func load(_ url: URL, type: AssetType) async throws -> any Asset
}

public final class Asset {
    public enum GLB { public let mesh, skeleton, animations: [Animation], textures: [URI] }
    public enum KTX2 { public let width, height, mipCount, format }
    public enum Shader { public let sourceHash: String }
}

public final class MemoryCache {
    public init(footprintBytes: Int) // Phase 1: 32 MB cap
    public func get(_ key: String) -> (any Asset)?
    public func put(_ asset: any Asset, key: String, bytes: Int)
}

public final class DiskCache {  // interface only in Phase 1
    public init(rootDirectory: URL)
    public func metadata(for url: URL) async -> Data?
    public func write(_ data: Data, for url: URL) async throws
}
```

## Invariants

- Single-flight: 50 concurrent `load()` calls of the same URL share one decode.
- LRU eviction when memory footprint > 32 MB.
- Cache key = SHA-256 of file bytes, not file path.

## Error Modes

| Method | Throws |
|---|---|
| `load` | `AssetLoadError.<case>` (typed) |
| `DiskCache.write` | `I/O` errors |
| `MemoryCache.put` | Silent no-op if footprint exceeds; warn log |

## Test Hooks

- `AssetLoaderMock`: returns predefined `.GLB`/`.KTX2`/`.Shader` without decode.
- `MemoryCacheSpy`: counts evictions.
- `GLBFixture`: under `Tests/DPAssetTests/Fixtures/fox.glb`.

## Status

**Stub**. Filled when `spec-004-asset.md` lands.
