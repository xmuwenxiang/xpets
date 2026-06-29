import Foundation
import ImageIO
import CoreGraphics

/// Decodes a PNG (or JPEG, via ImageIO) `Data` into an RGBA8 `DecodedImage`.
/// macOS-only (Apple Silicon gate already enforced by the runtime). MTLTexture
/// upload is deferred to spec-002b.
public enum PNGDecoder {
    public static func decode(_ data: Data) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        let bytesPerRow = w * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * h)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return DecodedImage(rgba: rgba, width: w, height: h)
    }
}