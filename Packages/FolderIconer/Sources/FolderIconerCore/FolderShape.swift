import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Supplies the folder artwork. Its alpha is also the mask for "clip to folder".
public protocol FolderShapeProvider: Sendable { func folderImage(pixels: Int) -> CGImage }

/// The current OS folder icon, drawn per size into an sRGB bitmap and cached.
public final class SystemFolderShape: FolderShapeProvider, @unchecked Sendable {
    public static let shared = SystemFolderShape()
    private let lock = NSLock()
    private var icon: NSImage?
    private var cache: [Int: CGImage] = [:]

    public func folderImage(pixels: Int) -> CGImage {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[pixels] { return cached }
        let icon = self.icon ?? NSWorkspace.shared.icon(for: .folder); self.icon = icon
        let context = Bitmap.context(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let image = context.makeImage()!; cache[pixels] = image; return image
    }
}

/// An OS-independent folder silhouette with a vertical gray gradient, for snapshots.
public struct FixtureFolderShape: FolderShapeProvider {
    public init() {}
    public func folderImage(pixels: Int) -> CGImage {
        let n = CGFloat(pixels), context = Bitmap.context(width: pixels, height: pixels)
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: 0.08 * n, y: 0.66 * n, width: 0.36 * n, height: 0.14 * n), cornerWidth: 0.04 * n, cornerHeight: 0.04 * n)
        path.addRoundedRect(in: CGRect(x: 0.08 * n, y: 0.14 * n, width: 0.84 * n, height: 0.6 * n), cornerWidth: 0.06 * n, cornerHeight: 0.06 * n)
        context.addPath(path); context.clip()
        let colors = [0.55, 0.85].map { CGColor(colorSpace: Bitmap.sRGB, components: [$0, $0, $0, 1])! } as CFArray
        let gradient = CGGradient(colorsSpace: Bitmap.sRGB, colors: colors, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0.14 * n), end: CGPoint(x: 0, y: 0.8 * n), options: [])
        return context.makeImage()!
    }
}

/// Recolours a folder so its mean colour equals the target while keeping relative shading.
public enum FolderRecolor {
    public static func apply(_ folder: CGImage, color: RGBAColor) -> CGImage {
        var px = Bitmap.rgba(folder)
        func luminance(_ i: Int) -> Double {
            let a = Double(px[i + 3]); guard a > 0 else { return 0 }
            return (0.2126 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.0722 * Double(px[i + 2])) / a
        }
        var sum = 0.0, count = 0.0
        for i in stride(from: 0, to: px.count, by: 4) where px[i + 3] > 127 { sum += luminance(i); count += 1 }
        let mean = count > 0 ? sum / count : 1
        let target = [color.r, color.g, color.b]
        for i in stride(from: 0, to: px.count, by: 4) where px[i + 3] > 0 {
            let factor = mean > 0 ? luminance(i) / mean : 1
            let alpha = Double(px[i + 3]) / 255 * color.a
            for c in 0..<3 { px[i + c] = UInt8((min(max(target[c] * factor, 0), 1) * alpha * 255).rounded()) }
            px[i + 3] = UInt8((alpha * 255).rounded())
        }
        return Bitmap.image(rgba: px, width: folder.width, height: folder.height)
    }
}
