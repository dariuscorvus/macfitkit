import Foundation

extension IconDocument: Codable {
    private enum CodingKeys: String, CodingKey { case format, id, layers }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let format = try c.decode(Int.self, forKey: .format)
        guard format <= Self.format else { throw DocumentError.unsupportedFormat(format) }
        id = try c.decode(UUID.self, forKey: .id); layers = try c.decode([Layer].self, forKey: .layers)
        guard layers.filter(\.content.isFolderBase).count <= 1 else { throw DocumentError.multipleFolderBases }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.format, forKey: .format); try c.encode(id, forKey: .id); try c.encode(layers, forKey: .layers)
    }
    public static func decode(_ data: Data) throws -> IconDocument { try JSONDecoder().decode(IconDocument.self, from: data) }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }
}

// Missing keys fall back to defaults so later releases can add layer properties without a format bump.
extension Layer: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, visible, locked, opacity, blendMode, transform, clipToFolder, hideBelowSize, effects, content }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        content = try c.decode(LayerContent.self, forKey: .content)
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true; locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        blendMode = try c.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
        transform = try c.decodeIfPresent(LayerTransform.self, forKey: .transform) ?? .init()
        clipToFolder = try c.decodeIfPresent(Bool.self, forKey: .clipToFolder) ?? false
        hideBelowSize = try c.decodeIfPresent(Int.self, forKey: .hideBelowSize)
        effects = try c.decodeIfPresent([LayerEffect].self, forKey: .effects) ?? []
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(visible, forKey: .visible); try c.encode(locked, forKey: .locked)
        try c.encode(opacity, forKey: .opacity); try c.encode(blendMode, forKey: .blendMode); try c.encode(transform, forKey: .transform)
        try c.encode(clipToFolder, forKey: .clipToFolder); try c.encode(hideBelowSize, forKey: .hideBelowSize)
        try c.encode(effects, forKey: .effects); try c.encode(content, forKey: .content)
    }
}

private struct TypeKey: CodingKey {
    static let type = TypeKey(stringValue: "type")
    var stringValue: String; var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private extension Decoder {
    func typeName() throws -> String { try container(keyedBy: TypeKey.self).decode(String.self, forKey: .type) }
}

private extension Encoder {
    // The payload's own keys land next to "type" in the same JSON object.
    func encode(type: String, _ payload: some Encodable) throws {
        var c = container(keyedBy: TypeKey.self); try c.encode(type, forKey: .type); try payload.encode(to: self)
    }
}

extension LayerContent: Codable {
    public var typeName: String {
        switch self { case .folderBase: "folderBase"; case .image: "image"; case .text: "text"; case .emoji: "emoji" }
    }
    public init(from decoder: any Decoder) throws {
        switch try decoder.typeName() {
        case "folderBase": self = .folderBase(try FolderBase(from: decoder))
        case "image": self = .image(try ImageContent(from: decoder))
        case "text": self = .text(try TextContent(from: decoder))
        case "emoji": self = .emoji(try EmojiContent(from: decoder))
        case let other: throw DocumentError.unknownLayerType(other)
        }
    }
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .folderBase(let base): try encoder.encode(type: typeName, base)
        case .image(let image): try encoder.encode(type: typeName, image)
        case .text(let text): try encoder.encode(type: typeName, text)
        case .emoji(let emoji): try encoder.encode(type: typeName, emoji)
        }
    }
}

extension LayerEffect: Codable {
    public var typeName: String {
        switch self { case .outline: "outline"; case .dropShadow: "dropShadow"; case .innerShadow: "innerShadow"; case .outerGlow: "outerGlow"; case .innerGlow: "innerGlow" }
    }
    public var isEnabled: Bool {
        switch self { case .outline(let e): e.enabled; case .dropShadow(let e), .innerShadow(let e): e.enabled; case .outerGlow(let e), .innerGlow(let e): e.enabled }
    }
    public init(from decoder: any Decoder) throws {
        switch try decoder.typeName() {
        case "outline": self = .outline(try Outline(from: decoder))
        case "dropShadow": self = .dropShadow(try Shadow(from: decoder))
        case "innerShadow": self = .innerShadow(try Shadow(from: decoder))
        case "outerGlow": self = .outerGlow(try Glow(from: decoder))
        case "innerGlow": self = .innerGlow(try Glow(from: decoder))
        case let other: throw DocumentError.unknownEffectType(other)
        }
    }
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .outline(let e): try encoder.encode(type: typeName, e)
        case .dropShadow(let e), .innerShadow(let e): try encoder.encode(type: typeName, e)
        case .outerGlow(let e), .innerGlow(let e): try encoder.encode(type: typeName, e)
        }
    }
}

/// `{"solid": {r,g,b,a}}` or `{"linear": {"stops": […], "angle": 0}}`.
extension Fill: Codable {
    private enum CodingKeys: String, CodingKey { case solid, linear }
    private struct Linear: Codable { var stops: [GradientStop]; var angle: Double }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let color = try c.decodeIfPresent(RGBAColor.self, forKey: .solid) { self = .solid(color); return }
        let linear = try c.decode(Linear.self, forKey: .linear); self = .linear(stops: linear.stops, angle: linear.angle)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .solid(let color): try c.encode(color, forKey: .solid)
        case .linear(let stops, let angle): try c.encode(Linear(stops: stops, angle: angle), forKey: .linear)
        }
    }
}
