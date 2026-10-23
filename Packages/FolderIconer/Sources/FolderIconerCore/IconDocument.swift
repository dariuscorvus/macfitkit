import Foundation

/// A folder icon: an ordered layer stack, bottom → top. At most one layer is a folder base.
public struct IconDocument: Hashable, Sendable {
    public static let format = 1
    public var id: UUID
    public var layers: [Layer]
    public init(id: UUID = UUID(), layers: [Layer]) { self.id = id; self.layers = layers }
}

/// One layer with the properties every kind shares.
public struct Layer: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var visible = true, locked = false
    public var opacity: Double = 1
    public var blendMode: BlendMode = .normal
    public var transform = LayerTransform()
    public var clipToFolder = false
    /// Points. The layer is skipped when the rendered point size is smaller.
    public var hideBelowSize: Int? = nil
    /// Rendered in a fixed order whatever the array order; see `EffectRenderer`.
    public var effects: [LayerEffect] = []
    public var content: LayerContent
    public init(id: UUID = UUID(), name: String, content: LayerContent) { self.id = id; self.name = name; self.content = content }
}

/// x/y: centre in canvas units, origin top-left, y down. rotation: degrees, clockwise on screen.
public struct LayerTransform: Codable, Hashable, Sendable {
    public var x = 0.5, y = 0.5, scale = 1.0, rotation = 0.0, flipX = false, flipY = false
    public init(x: Double = 0.5, y: Double = 0.5, scale: Double = 1, rotation: Double = 0, flipX: Bool = false, flipY: Bool = false) {
        self.x = x; self.y = y; self.scale = scale; self.rotation = rotation; self.flipX = flipX; self.flipY = flipY
    }
}

/// Layer kinds. New kinds are added as cases here, in `LayerContent.typeName`, the coding switch and `LayerDrawing`.
public enum LayerContent: Hashable, Sendable {
    case folderBase(FolderBase), image(ImageContent), text(TextContent), emoji(EmojiContent)
    public var isFolderBase: Bool { if case .folderBase = self { true } else { false } }
    /// Assets the package must keep for this content.
    public var assetIDs: [AssetID] {
        switch self { case .image(let image): [image.asset]; case .folderBase, .text, .emoji: [] }
    }
}

public struct FolderBase: Codable, Hashable, Sendable {
    public enum Style: String, Codable, Sendable, CaseIterable { case system, color, none }
    public var style: Style
    public var color: RGBAColor
    public init(style: Style = .system, color: RGBAColor = .folderBlue) { self.style = style; self.color = color }
}

public struct ImageContent: Codable, Hashable, Sendable {
    public enum Fit: String, Codable, Sendable, CaseIterable { case fill, fit, crop }
    public var asset: AssetID
    public var size: CanvasSize
    public var fit: Fit
    /// Normalised image coordinates, origin top-left. Used by `.crop`.
    public var crop: NormalizedRect?
    public var adjust: ImageAdjustments
    public init(asset: AssetID, size: CanvasSize = .init(width: 1, height: 1), fit: Fit = .fill, crop: NormalizedRect? = nil, adjust: ImageAdjustments = .init()) {
        self.asset = asset; self.size = size; self.fit = fit; self.crop = crop; self.adjust = adjust
    }
}

public struct ImageAdjustments: Codable, Hashable, Sendable {
    /// hue: degrees. brightness: -1…1 added. blur: canvas units.
    public var hue = 0.0, saturation = 1.0, brightness = 0.0, blur = 0.0
    public var colorize: Colorize?
    public init(hue: Double = 0, saturation: Double = 1, brightness: Double = 0, blur: Double = 0, colorize: Colorize? = nil) {
        self.hue = hue; self.saturation = saturation; self.brightness = brightness; self.blur = blur; self.colorize = colorize
    }
    public var isIdentity: Bool { hue == 0 && saturation == 1 && brightness == 0 && blur == 0 && colorize == nil }
}

public struct Colorize: Codable, Hashable, Sendable {
    public var color: RGBAColor
    public var intensity: Double
    public init(color: RGBAColor, intensity: Double = 1) { self.color = color; self.intensity = intensity }
}

public struct TextContent: Codable, Hashable, Sendable {
    public var string: String
    /// nil = system font.
    public var fontFamily: String?
    public var weight: FontWeight
    /// size: canvas units. tracking: em.
    public var size: Double, tracking: Double
    public var fill: Fill
    public init(string: String, fontFamily: String? = nil, weight: FontWeight = .bold, size: Double = 0.12, tracking: Double = 0, fill: Fill = .solid(.white)) {
        self.string = string; self.fontFamily = fontFamily; self.weight = weight; self.size = size; self.tracking = tracking; self.fill = fill
    }
}

public struct EmojiContent: Codable, Hashable, Sendable {
    public var character: String
    /// Canvas units.
    public var size: Double
    public init(character: String, size: Double = 0.3) { self.character = character; self.size = size }
    /// Exactly one grapheme cluster that starts with a non-ASCII emoji scalar.
    public static func accepts(_ string: String) -> Bool {
        guard string.count == 1, let first = string.unicodeScalars.first else { return false }
        return first.properties.isEmoji && !first.isASCII
    }
}

public enum FontWeight: String, Codable, Hashable, Sendable, CaseIterable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

public enum Fill: Hashable, Sendable {
    case solid(RGBAColor), linear(stops: [GradientStop], angle: Double)
}

public struct GradientStop: Codable, Hashable, Sendable {
    public var color: RGBAColor
    /// 0…1 along the gradient.
    public var location: Double
    public init(color: RGBAColor, location: Double) { self.color = color; self.location = location }
}

/// sRGB, 0…1.
public struct RGBAColor: Codable, Hashable, Sendable {
    public var r, g, b, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public static let white = RGBAColor(r: 1, g: 1, b: 1), black = RGBAColor(r: 0, g: 0, b: 0)
    public static let folderBlue = RGBAColor(r: 0.36, g: 0.74, b: 0.92)
}

/// Canvas units: 1.0 is the canvas edge.
public struct CanvasSize: Codable, Hashable, Sendable {
    public var width, height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

public struct NormalizedRect: Codable, Hashable, Sendable {
    public var x, y, width, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) { self.x = x; self.y = y; self.width = width; self.height = height }
}

/// 1:1 to `CGBlendMode`.
public enum BlendMode: String, Codable, Hashable, Sendable, CaseIterable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity
}

/// Lengths in canvas units. One effect of each kind per layer; render order is fixed, not array order (#20).
public enum LayerEffect: Hashable, Sendable {
    case outline(Outline), dropShadow(Shadow), innerShadow(Shadow), outerGlow(Glow), innerGlow(Glow)
    public struct Outline: Codable, Hashable, Sendable {
        public var enabled = true; public var color: RGBAColor; public var width: Double
        public init(enabled: Bool = true, color: RGBAColor, width: Double) { self.enabled = enabled; self.color = color; self.width = width }
    }
    public struct Shadow: Codable, Hashable, Sendable {
        public var enabled = true; public var color: RGBAColor; public var dx, dy, blur: Double
        public init(enabled: Bool = true, color: RGBAColor, dx: Double, dy: Double, blur: Double) {
            self.enabled = enabled; self.color = color; self.dx = dx; self.dy = dy; self.blur = blur
        }
    }
    /// `spread` applies to the outer glow only.
    public struct Glow: Codable, Hashable, Sendable {
        public var enabled = true; public var color: RGBAColor; public var blur: Double, spread: Double
        public init(enabled: Bool = true, color: RGBAColor, blur: Double, spread: Double = 0) { self.enabled = enabled; self.color = color; self.blur = blur; self.spread = spread }
    }
}

public enum DocumentError: LocalizedError, Equatable, Sendable {
    case unsupportedFormat(Int), unknownLayerType(String), unknownEffectType(String), multipleFolderBases, missingAsset(AssetID)
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format): "Unsupported document format \(format)."
        case .unknownLayerType(let type): "Unknown layer type \(type)."
        case .unknownEffectType(let type): "Unknown effect type \(type)."
        case .multipleFolderBases: "A document can have only one folder base."
        case .missingAsset(let asset): "Missing asset \(asset)."
        }
    }
}
