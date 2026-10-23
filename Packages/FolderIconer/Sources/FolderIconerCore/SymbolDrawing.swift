import AppKit

/// SF Symbols through `NSImage`, drawn as vectors at the output pixel size. An unknown name draws nothing.
public enum SymbolDrawing {
    public static func exists(_ name: String) -> Bool { NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil }

    static func image(_ symbol: SymbolContent, pixels: CGFloat) -> NSImage? {
        var config = NSImage.SymbolConfiguration(pointSize: max(1, pixels), weight: symbol.weight.nsWeight)
        let colors = symbol.colors.map(\.nsColor), first = colors.first ?? .white
        switch symbol.rendering {
        case .monochrome: config = config.applying(.init(paletteColors: [first]))
        case .hierarchical: config = config.applying(.init(hierarchicalColor: first))
        case .palette: config = config.applying(.init(paletteColors: colors.isEmpty ? [first] : Array(colors.prefix(3))))
        case .multicolor: config = config.applying(.preferringMulticolor())
        }
        return NSImage(systemSymbolName: symbol.name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    /// Canvas units, measured at `pixels` per unit.
    static func size(_ symbol: SymbolContent, pixelsPerUnit unit: CGFloat) -> CGSize {
        guard let image = image(symbol, pixels: symbol.size * unit) else { return CGSize(width: symbol.size, height: symbol.size) }
        return CGSize(width: image.size.width / unit, height: image.size.height / unit)
    }

    /// The context is in pixels, y up, centred on the layer origin.
    static func draw(_ symbol: SymbolContent, pixelsPerUnit unit: CGFloat, in context: CGContext) {
        guard let image = image(symbol, pixels: symbol.size * unit) else { return }
        NSGraphics.draw(in: context) { image.draw(in: image.size.centeredBox) }
    }
}

enum NSGraphics {
    /// Runs AppKit drawing against a CG context. `NSGraphicsContext.current` is per thread, so this is safe off the main thread.
    static func draw(in context: CGContext, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false); body()
    }
}

extension RGBAColor {
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
}
