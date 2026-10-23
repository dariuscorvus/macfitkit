import CoreGraphics
import CoreImage

/// Layer effects as a Core Image graph over the finished layer image `A` (N×N, y up). Lengths are canvas units × N.
/// Stack bottom → top: drop shadow, outer glow, outline, A, inner shadow, inner glow, whatever the array order.
enum EffectRenderer {
    /// nil when no effect is enabled with a non-zero size, so the layer stays byte-identical to one without effects.
    static func apply(_ effects: [LayerEffect], to layer: CGImage, pixels: Int, context: CIContext) -> CGImage? {
        let n = CGFloat(pixels), a = CIImage(cgImage: layer), canvas = CGRect(x: 0, y: 0, width: n, height: n)
        func tint(_ image: CIImage, _ color: RGBAColor) -> CIImage { constant(color).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: image]) }
        func outside(_ color: RGBAColor) -> CIImage { constant(color).applyingFilter("CISourceOutCompositing", parameters: [kCIInputBackgroundImageKey: a]) }
        func inside(_ image: CIImage) -> CIImage { image.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: a]) }
        func blur(_ image: CIImage, _ radius: Double) -> CIImage {
            radius > 0 ? image.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius * n]) : image
        }
        func grow(_ image: CIImage, _ radius: Double) -> CIImage {
            radius > 0 ? image.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius * n]) : image
        }
        func offset(_ image: CIImage, _ dx: Double, _ dy: Double) -> CIImage { image.transformed(by: CGAffineTransform(translationX: dx * n, y: -dy * n)) }

        var below: [CIImage] = [], above: [CIImage] = []
        for effect in ordered(effects) {
            switch effect {
            case .dropShadow(let e): below.append(offset(blur(tint(a, e.color), e.blur), e.dx, e.dy))
            case .outerGlow(let e): below.append(blur(tint(grow(a, e.spread), e.color), e.blur))
            case .outline(let e): below.append(tint(grow(a, e.width), e.color))
            case .innerShadow(let e): above.append(inside(blur(offset(outside(e.color), e.dx, e.dy), e.blur)))
            case .innerGlow(let e): above.append(inside(blur(outside(e.color), e.blur)))
            }
        }
        guard !below.isEmpty || !above.isEmpty else { return nil }
        let stack = below + [a] + above
        let output = stack.dropFirst().reduce(stack[0]) { $1.composited(over: $0) }.cropped(to: canvas)
        return context.createCGImage(output, from: canvas, format: .RGBA8, colorSpace: Bitmap.sRGB)
    }

    /// Enabled effects with a visible size, one per kind (the first wins), in render order.
    static func ordered(_ effects: [LayerEffect]) -> [LayerEffect] {
        let order = ["dropShadow", "outerGlow", "outline", "innerShadow", "innerGlow"]
        var seen = Set<String>()
        return effects.filter { $0.isEnabled && $0.isVisible && seen.insert($0.typeName).inserted }
            .sorted { order.firstIndex(of: $0.typeName)! < order.firstIndex(of: $1.typeName)! }
    }

    private static func constant(_ color: RGBAColor) -> CIImage {
        CIImage(color: CIColor(red: color.r, green: color.g, blue: color.b, alpha: color.a, colorSpace: Bitmap.sRGB)!)
    }
}

extension LayerEffect {
    /// A zero outline or an unblurred, unshifted shadow/glow adds nothing visible.
    var isVisible: Bool {
        switch self {
        case .outline(let e): e.width > 0 && e.color.a > 0
        case .dropShadow(let e): e.color.a > 0 && (e.blur > 0 || e.dx != 0 || e.dy != 0)
        case .innerShadow(let e): e.color.a > 0 && (e.blur > 0 || e.dx != 0 || e.dy != 0)
        case .outerGlow(let e): e.color.a > 0 && (e.blur > 0 || e.spread > 0)
        case .innerGlow(let e): e.color.a > 0 && e.blur > 0
        }
    }
}
