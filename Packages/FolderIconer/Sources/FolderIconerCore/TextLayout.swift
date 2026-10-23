import AppKit
import CoreText

/// Centred lines of text laid out at a fixed pixel scale. Sizes are in pixels.
struct TextLayout {
    struct Line { let line: CTLine; let ascent, descent, leading, width: CGFloat }
    let lines: [Line]
    let fontPixels: CGFloat
    var size: CGSize { CGSize(width: lines.map(\.width).max() ?? 0, height: lines.reduce(0) { $0 + $1.ascent + $1.descent + $1.leading }) }

    init(_ string: String, font: CTFont, tracking: Double, color: CGColor?) {
        fontPixels = CTFontGetSize(font)
        var attributes: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): font, .init(kCTKernAttributeName as String): tracking * fontPixels]
        if let color { attributes[.init(kCTForegroundColorAttributeName as String)] = color }
        lines = string.components(separatedBy: "\n").map { text in
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            // Empty lines keep the font's line height.
            if text.isEmpty { return Line(line: line, ascent: CTFontGetAscent(font), descent: CTFontGetDescent(font), leading: CTFontGetLeading(font), width: 0) }
            return Line(line: line, ascent: ascent, descent: descent, leading: leading, width: width)
        }
    }

    /// Draws the lines centred on the origin of a y-up context whose unit is one pixel.
    func draw(in context: CGContext) {
        context.textMatrix = .identity
        var top = size.height / 2
        for line in lines {
            context.textPosition = CGPoint(x: -line.width / 2, y: top - line.ascent)
            CTLineDraw(line.line, context); top -= line.ascent + line.descent + line.leading
        }
    }

    static func font(_ text: TextContent, pixels: CGFloat) -> CTFont {
        if let family = text.fontFamily {
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family, .traits: [NSFontDescriptor.TraitKey.weight: text.weight.nsWeight]])
            if let font = NSFont(descriptor: descriptor, size: pixels), font.familyName == family { return font as CTFont }
        }
        return NSFont.systemFont(ofSize: pixels, weight: text.weight.nsWeight) as CTFont
    }

    static func emojiFont(pixels: CGFloat) -> CTFont { CTFontCreateWithName("AppleColorEmoji" as CFString, pixels, nil) }
}

public extension TextContent {
    /// The renderer's font at `points`, for the editor's inline text field.
    func font(points: CGFloat) -> NSFont { TextLayout.font(self, pixels: points) as NSFont }
}

extension FontWeight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .ultraLight: .ultraLight; case .thin: .thin; case .light: .light; case .regular: .regular; case .medium: .medium
        case .semibold: .semibold; case .bold: .bold; case .heavy: .heavy; case .black: .black
        }
    }
}
