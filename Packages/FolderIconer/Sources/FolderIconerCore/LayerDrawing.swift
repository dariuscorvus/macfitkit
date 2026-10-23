import CoreGraphics
import CoreText

/// Per-kind drawing. The context arrives with the layer transform applied: one unit is the canvas edge, content centred at the origin, y up.
extension IconRenderer {
    /// Pixels per canvas unit used to measure text, so the box does not depend on the output size.
    static let measureScale: CGFloat = 1024

    public func contentSize(of layer: Layer, in package: DocumentPackage) -> CGSize {
        switch layer.content {
        case .folderBase: return CGSize(width: 1, height: 1)
        case .image(let image): return CGSize(width: image.size.width, height: image.size.height)
        case .text(let text): return measured(textLayout(text, pixelsPerUnit: Self.measureScale))
        case .emoji(let emoji): return measured(emojiLayout(emoji, pixelsPerUnit: Self.measureScale))
        }
    }

    func draw(_ content: LayerContent, from package: DocumentPackage, in context: CGContext, pixels: Int, pixelsPerUnit unit: CGFloat) {
        switch content {
        case .folderBase(let base):
            guard let image = folderImage(base, pixels: pixels) else { return }
            context.draw(image, in: CGSize(width: 1, height: 1).centeredBox)
        case .image(let image): drawImage(image, from: package, in: context, canvasPixels: CGFloat(pixels), pixelsPerUnit: unit)
        case .text(let text):
            let layout = textLayout(text, pixelsPerUnit: unit)
            context.scaleBy(x: 1 / unit, y: 1 / unit)
            switch text.fill {
            case .solid: layout.draw(in: context)
            case .linear(let stops, let angle): drawGradient(layout, stops: stops, angle: angle, in: context)
            }
        case .emoji(let emoji):
            let layout = emojiLayout(emoji, pixelsPerUnit: unit)
            context.scaleBy(x: 1 / unit, y: 1 / unit); layout.draw(in: context)
        }
    }

    private func measured(_ layout: TextLayout) -> CGSize {
        CGSize(width: layout.size.width / Self.measureScale, height: layout.size.height / Self.measureScale)
    }

    func textLayout(_ text: TextContent, pixelsPerUnit unit: CGFloat) -> TextLayout {
        let color: CGColor? = if case .solid(let fill) = text.fill { fill.cgColor } else { RGBAColor.white.cgColor }
        return TextLayout(text.string, font: TextLayout.font(text, pixels: max(1, text.size * unit)), tracking: text.tracking, color: color)
    }

    func emojiLayout(_ emoji: EmojiContent, pixelsPerUnit unit: CGFloat) -> TextLayout {
        TextLayout(emoji.character, font: TextLayout.emojiFont(pixels: max(1, emoji.size * unit)), tracking: 0, color: nil)
    }

    private func drawImage(_ content: ImageContent, from package: DocumentPackage, in context: CGContext, canvasPixels: CGFloat, pixelsPerUnit unit: CGFloat) {
        guard let decoded = decodedAsset(content.asset, from: package) else { return }
        let placement = ImageLoading.placement(content, image: decoded)
        guard var image = placement.source.size == CGSize(width: decoded.width, height: decoded.height) ? decoded : decoded.cropping(to: placement.source) else { return }
        if !content.adjust.isIdentity {
            let pixels = CGSize(width: placement.destination.width * unit, height: placement.destination.height * unit)
            guard let adjusted = ImageLoading.adjusted(image, content.adjust, pixels: pixels, canvasPixels: canvasPixels, context: ciContext) else { return }
            image = adjusted
        }
        if placement.clip { context.clip(to: CGSize(width: content.size.width, height: content.size.height).centeredBox) }
        context.draw(image, in: placement.destination)
    }

    /// Glyphs become an 8-bit gray mask; the gradient is painted through it across the text box at `angle` (degrees, clockwise).
    private func drawGradient(_ layout: TextLayout, stops: [GradientStop], angle: Double, in context: CGContext) {
        let box = layout.size.centeredBox, pad = layout.fontPixels * 0.25
        let maskRect = box.insetBy(dx: -pad, dy: -pad).integral
        guard maskRect.width > 0, maskRect.height > 0,
              let mask = CGContext(data: nil, width: Int(maskRect.width), height: Int(maskRect.height), bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        mask.translateBy(x: -maskRect.minX, y: -maskRect.minY); layout.draw(in: mask)
        guard let maskImage = mask.makeImage() else { return }
        context.clip(to: maskRect, mask: maskImage)
        FillPainter.linear(stops: stops, angle: angle, box: box, in: context)
    }
}
