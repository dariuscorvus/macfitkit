import AppKit
import CoreGraphics
import CoreImage

public struct RenderOptions: Sendable {
    public var folder: any FolderShapeProvider
    public init(folder: any FolderShapeProvider = SystemFolderShape.shared) { self.folder = folder }
}

/// Renders documents into sRGB, premultiplied RGBA8 images. One renderer serves the editor preview and the applied icon.
public final class IconRenderer: @unchecked Sendable {
    public let options: RenderOptions
    let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()
    private var decoded: [AssetID: CGImage] = [:]
    private var recolored: [RecolorKey: CGImage] = [:]
    private struct RecolorKey: Hashable { let pixels: Int; let color: RGBAColor }

    public init(options: RenderOptions = .init()) { self.options = options }

    public func render(_ package: DocumentPackage, size: IconSize) -> CGImage { render(package, points: size.points, scale: size.scale) }

    /// Each layer is drawn into its own canvas so opacity, blend mode and the folder clip apply to the finished layer.
    public func render(_ package: DocumentPackage, points: Int, scale: Int) -> CGImage {
        let n = max(1, points * scale), full = CGRect(x: 0, y: 0, width: n, height: n)
        let canvas = Bitmap.context(width: n, height: n)
        for layer in package.document.layers where layer.visible && points >= (layer.hideBelowSize ?? 0) {
            let context = Bitmap.context(width: n, height: n)
            context.saveGState(); context.concatenate(layer.transform.affine(pixels: n))
            draw(layer.content, from: package, in: context, pixels: n, pixelsPerUnit: CGFloat(n) * max(abs(layer.transform.scale), 0.001))
            context.restoreGState()
            // Effects come before the clip, so the folder clip also cuts shadows and glows.
            if !layer.effects.isEmpty, let content = context.makeImage(), let effected = EffectRenderer.apply(layer.effects, to: content, pixels: n, context: ciContext) {
                context.clear(full); context.draw(effected, in: full)
            }
            if layer.clipToFolder { context.setBlendMode(.destinationIn); context.draw(options.folder.folderImage(pixels: n), in: full) }
            guard let image = context.makeImage() else { continue }
            canvas.saveGState(); canvas.setAlpha(min(max(layer.opacity, 0), 1)); canvas.setBlendMode(layer.blendMode.cg)
            canvas.draw(image, in: full); canvas.restoreGState()
        }
        return canvas.makeImage()!
    }

    /// The 10 iconset representations, each with its point size, ready for `NSWorkspace.setIcon`.
    public func iconImage(_ package: DocumentPackage) -> NSImage {
        let image = NSImage(size: NSSize(width: 512, height: 512))
        for size in IconSize.iconset {
            let rep = NSBitmapImageRep(cgImage: render(package, size: size))
            rep.size = NSSize(width: size.points, height: size.points); image.addRepresentation(rep)
        }
        return image
    }

    func folderImage(_ base: FolderBase, pixels: Int) -> CGImage? {
        switch base.style {
        case .none: return nil
        case .system: return options.folder.folderImage(pixels: pixels)
        case .color:
            let key = RecolorKey(pixels: pixels, color: base.color)
            if let cached = locked({ recolored[key] }) { return cached }
            let image = FolderRecolor.apply(options.folder.folderImage(pixels: pixels), color: base.color)
            locked { recolored[key] = image }; return image
        }
    }

    func decodedAsset(_ id: AssetID, from package: DocumentPackage) -> CGImage? {
        if let cached = locked({ decoded[id] }) { return cached }
        guard let data = package.assets[id], let image = ImageLoading.decode(data) else { return nil }
        locked { decoded[id] = image }; return image
    }

    private func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
}

extension BlendMode {
    var cg: CGBlendMode {
        switch self {
        case .normal: .normal; case .multiply: .multiply; case .screen: .screen; case .overlay: .overlay; case .darken: .darken; case .lighten: .lighten
        case .colorDodge: .colorDodge; case .colorBurn: .colorBurn; case .softLight: .softLight; case .hardLight: .hardLight; case .difference: .difference
        case .exclusion: .exclusion; case .hue: .hue; case .saturation: .saturation; case .color: .color; case .luminosity: .luminosity
        }
    }
}
