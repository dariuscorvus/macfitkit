import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// sRGB-tagged 8-bit premultiplied RGBA bitmaps. Untagged device RGB shifts colours once it passes through `setIcon`.
public enum Bitmap {
    public static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    static let info = CGImageAlphaInfo.premultipliedLast.rawValue

    public static func context(width: Int, height: Int) -> CGContext {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB, bitmapInfo: info)!
        context.interpolationQuality = .high; return context
    }

    /// Premultiplied RGBA8 bytes in sRGB, rows top → bottom.
    public static func rgba(_ image: CGImage) -> [UInt8] {
        let (w, h) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: sRGB, bitmapInfo: info)!
            context.setBlendMode(.copy); context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return bytes
    }

    public static func image(rgba bytes: [UInt8], width: Int, height: Int) -> CGImage {
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: sRGB,
                       bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }

    public static func png(_ image: CGImage) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil); CGImageDestinationFinalize(destination)
        return data as Data
    }

    public static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

extension RGBAColor {
    var cgColor: CGColor { CGColor(colorSpace: Bitmap.sRGB, components: [r, g, b, a].map { CGFloat($0) })! }
}
