import CoreGraphics
import Foundation

/// Fixtures for effects, symbols, vectors and shapes (#20).
extension IconFixtures {
    static let kindNames = ["effect-outline", "effect-drop-shadow", "effect-inner-shadow", "effect-outer-glow", "effect-inner-glow", "effects-all",
                            "symbol-palette", "symbol-multicolor", "vector-svg", "vector-svg-filter", "vector-pdf", "shape-rounded", "shape-circle-clipped"]

    /// Adds the fixture's layers, or returns false for an unknown name.
    static func addKindFixture(_ name: String, to package: inout DocumentPackage) -> Bool {
        func add(_ name: String, _ content: LayerContent, _ edit: (inout Layer) -> Void = { _ in }) {
            var layer = Layer(id: id(package.document.layers.count + 1), name: name, content: content); edit(&layer); package.document.layers.append(layer)
        }
        let orange = RGBAColor(r: 1, g: 0.6, b: 0.15), ink = RGBAColor(r: 0.1, g: 0.15, b: 0.3)
        let tile = LayerContent.shape(ShapeContent(size: CanvasSize(width: 0.36, height: 0.36), cornerRadius: 0.07, fill: .solid(orange)))
        func effect(_ effect: LayerEffect) { add("Tile", tile) { $0.transform.y = 0.55; $0.effects = [effect] } }
        switch name {
        case "effect-outline": effect(.outline(.init(color: ink, width: 0.02)))
        case "effect-drop-shadow": effect(.dropShadow(.init(color: RGBAColor(r: 0, g: 0, b: 0, a: 0.6), dx: 0.03, dy: 0.04, blur: 0.02)))
        case "effect-inner-shadow": effect(.innerShadow(.init(color: RGBAColor(r: 0, g: 0, b: 0, a: 0.7), dx: 0.02, dy: 0.03, blur: 0.015)))
        case "effect-outer-glow": effect(.outerGlow(.init(color: RGBAColor(r: 1, g: 0.95, b: 0.3), blur: 0.04, spread: 0.01)))
        case "effect-inner-glow": effect(.innerGlow(.init(color: .white, blur: 0.04)))
        case "effects-all":
            add("Label", .text(TextContent(string: "Fx", weight: .heavy, size: 0.3, fill: .solid(orange)))) {
                $0.transform.y = 0.56
                // Array order is deliberately not render order; the disabled outline must not render.
                $0.effects = [.innerGlow(.init(color: .white, blur: 0.01)), .outline(.init(color: ink, width: 0.012)),
                              .innerShadow(.init(color: RGBAColor(r: 0.5, g: 0.1, b: 0, a: 0.8), dx: 0.006, dy: 0.008, blur: 0.004)),
                              .outerGlow(.init(color: RGBAColor(r: 1, g: 1, b: 0.6), blur: 0.03, spread: 0.008)),
                              .dropShadow(.init(color: RGBAColor(r: 0, g: 0, b: 0, a: 0.5), dx: 0.02, dy: 0.03, blur: 0.015)),
                              .outline(.init(enabled: false, color: RGBAColor(r: 1, g: 0, b: 0), width: 0.04))]
            }
        case "symbol-palette":
            add("Star", .symbol(SymbolContent(name: "star.circle.fill", size: 0.4, weight: .bold, rendering: .palette, colors: [.white, orange]))) { $0.transform.y = 0.56 }
        case "symbol-multicolor":
            add("Weather", .symbol(SymbolContent(name: "cloud.sun.rain.fill", size: 0.38, rendering: .multicolor))) { $0.transform = LayerTransform(x: 0.5, y: 0.56, rotation: -10) }
        case "vector-svg":
            let asset = package.addAsset(Data(ringSVG.utf8), pathExtension: "svg")
            add("Ring", .vector(VectorContent(asset: asset, size: CanvasSize(width: 0.5, height: 0.5)))) { $0.transform.y = 0.56 }
        case "vector-svg-filter":
            let asset = package.addAsset(Data(dropShadowSVG.utf8), pathExtension: "svg")
            add("Shadowed", .vector(VectorContent(asset: asset, size: CanvasSize(width: 0.5, height: 0.5)))) { $0.transform.y = 0.56 }
        case "vector-pdf":
            let asset = package.addAsset(badgePDF(), pathExtension: "pdf")
            add("Badge", .vector(VectorContent(asset: asset, size: CanvasSize(width: 0.6, height: 0.6)))) { $0.transform = LayerTransform(x: 0.5, y: 0.56, rotation: 15) }
        case "shape-rounded":
            let fill = Fill.linear(stops: [GradientStop(color: RGBAColor(r: 0.3, g: 0.85, b: 0.6), location: 0), GradientStop(color: RGBAColor(r: 0.1, g: 0.4, b: 0.7), location: 1)], angle: 90)
            add("Card", .shape(ShapeContent(size: CanvasSize(width: 0.56, height: 0.34), cornerRadius: 0.08, fill: fill, stroke: .init(color: .white, width: 0.015)))) { $0.transform.y = 0.56 }
        case "shape-circle-clipped":
            add("Dot", .shape(ShapeContent(kind: .circle, size: CanvasSize(width: 0.7, height: 0.7), fill: .solid(RGBAColor(r: 0.9, g: 0.2, b: 0.3, a: 0.85))))) {
                $0.transform = LayerTransform(x: 0.85, y: 0.8); $0.clipToFolder = true
            }
        default: return false
        }
        return true
    }

    /// A gradient ring cut by a mask, with a solid triangle on top.
    public static let ringSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
      <defs>
        <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffcc33"/><stop offset="1" stop-color="#e6337f"/></linearGradient>
        <mask id="m"><rect width="100" height="100" fill="white"/><circle cx="50" cy="50" r="24" fill="black"/></mask>
      </defs>
      <circle cx="50" cy="50" r="46" fill="url(#g)" mask="url(#m)"/>
      <path d="M38 60 L50 38 L62 60 Z" fill="#1d4d2b"/>
    </svg>
    """

    /// A white square with an `feDropShadow` filter. AppKit ignores the filter; layer effects are the supported way to get a shadow.
    public static let dropShadowSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
      <defs><filter id="s" x="-50%" y="-50%" width="200%" height="200%"><feDropShadow dx="6" dy="6" stdDeviation="4" flood-color="#000" flood-opacity="0.8"/></filter></defs>
      <rect x="20" y="20" width="56" height="56" rx="8" fill="#ffffff" filter="url(#s)"/>
    </svg>
    """

    /// A 200×100 pt one-page PDF: a navy rounded bar with a red disc in the centre.
    public static func badgePDF() -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 200, height: 100)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        context.beginPDFPage(nil)
        context.addPath(CGPath(roundedRect: box.insetBy(dx: 4, dy: 14), cornerWidth: 30, cornerHeight: 30, transform: nil))
        context.setFillColor(RGBAColor(r: 0.12, g: 0.18, b: 0.4).cgColor); context.fillPath()
        context.setFillColor(RGBAColor(r: 1, g: 0, b: 0).cgColor); context.fillEllipse(in: CGRect(x: 75, y: 25, width: 50, height: 50))
        context.endPDFPage(); context.closePDF()
        return data as Data
    }
}
