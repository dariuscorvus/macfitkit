import Foundation

/// An SF Symbol. size: point size in canvas units.
public struct SymbolContent: Codable, Hashable, Sendable {
    public enum Rendering: String, Codable, Sendable, CaseIterable { case monochrome, hierarchical, palette, multicolor }
    public var name: String
    public var size: Double
    public var weight: FontWeight
    public var rendering: Rendering
    /// monochrome and hierarchical use the first colour, palette up to three. Multicolor ignores them.
    public var colors: [RGBAColor]
    public init(name: String, size: Double = 0.3, weight: FontWeight = .regular, rendering: Rendering = .monochrome, colors: [RGBAColor] = [.white]) {
        self.name = name; self.size = size; self.weight = weight; self.rendering = rendering; self.colors = colors
    }
}

/// An imported SVG or PDF, aspect-fit inside `size`. The asset's extension picks the format.
public struct VectorContent: Codable, Hashable, Sendable {
    public enum Format: Sendable { case svg, pdf }
    public var asset: AssetID
    public var size: CanvasSize
    public init(asset: AssetID, size: CanvasSize = .init(width: 0.6, height: 0.6)) { self.asset = asset; self.size = size }
    public var format: Format? {
        switch (asset as NSString).pathExtension.lowercased() { case "svg": .svg; case "pdf": .pdf; default: nil }
    }
}

/// A filled and optionally stroked primitive. cornerRadius and stroke width: canvas units; the stroke is centred on the outline.
public struct ShapeContent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable { case rectangle, roundedRectangle, circle }
    public struct Stroke: Codable, Hashable, Sendable {
        public var color: RGBAColor; public var width: Double
        public init(color: RGBAColor, width: Double) { self.color = color; self.width = width }
    }
    public var kind: Kind
    public var size: CanvasSize
    public var cornerRadius: Double
    public var fill: Fill
    public var stroke: Stroke?
    public init(kind: Kind = .roundedRectangle, size: CanvasSize = .init(width: 0.4, height: 0.4), cornerRadius: Double = 0.06, fill: Fill = .solid(.white), stroke: Stroke? = nil) {
        self.kind = kind; self.size = size; self.cornerRadius = cornerRadius; self.fill = fill; self.stroke = stroke
    }
}
