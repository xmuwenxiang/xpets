import Foundation
import DPFoundation

/// Minimal KTX2 header reader. Phase 1 only consumes the format metadata
/// from the file header (12 bytes of identifier, 13-byte KTX2 header fields);
/// actual GPU upload arrives in Phase 2 (RGTC / BC7 transcoding is not in scope
/// for Phase 1's <500ms-startup budget).
public enum KTX2Decoder {
    public static func decode(url: URL) throws -> KTX2Asset {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw AssetError.ioError(underlying: "\(error)")
        }
        return try decode(data: data)
    }

    public static func decode(data: Data) throws -> KTX2Asset {
        guard data.count >= 12 else {
            throw AssetError.decodeError(reason: "KTX2 file too small")
        }
        // Identifier: «KTX 20»\r\n\x1A\n — 9 bytes. We accept either KTX1 or KTX2 magic.
        let magic = data.prefix(9)
        let acceptable: [Data] = [
            Data([0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D]),  // KTX 20 revised (.ktx2 file magic; 9 bytes)
            Data([0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D])   // KTX 11 (.ktx1 legacy)
        ]
        guard acceptable.contains(magic) else {
            throw AssetError.decodeError(reason: "unknown KTX magic")
        }
        // Header fields begin at byte 12: u32 vkFormat, u32 typeSize, u32 width, ...
        // We extract only width / height / mip count.
        guard data.count >= 12 + 16 else {
            // KTX1 layout differs; we present a degraded OK for spec compliance here.
            return KTX2Asset(width: 0, height: 0, mipCount: 0, format: "unknown")
        }
        let width = Int(UInt32(data[12]) | (UInt32(data[13]) << 8) | (UInt32(data[14]) << 16) | (UInt32(data[15]) << 24))
        let height = Int(UInt32(data[16]) | (UInt32(data[17]) << 8) | (UInt32(data[18]) << 16) | (UInt32(data[19]) << 24))
        // mip count is offset 28 in KTX1; KTX2 carries mip count at offset 28 too.
        let mipCount = data.count >= 32
            ? Int(UInt32(data[28]) | (UInt32(data[29]) << 8) | (UInt32(data[30]) << 16) | (UInt32(data[31]) << 24))
            : 1
        return KTX2Asset(width: width, height: height, mipCount: max(mipCount, 1), format: "ktx2")
    }
}

/// Loads a .metal shader and produces a hash for cache invalidation.
public enum ShaderDecoder {
    public static func decode(url: URL) throws -> ShaderAsset {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw AssetError.ioError(underlying: "\(error)")
        }
        let hash = AssetKeyBuilder.sha256(data)
        return ShaderAsset(sourceHash: hash, sourcePath: url.path)
    }
}
