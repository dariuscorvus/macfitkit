import Foundation
import Testing
@testable import FolderIconerCore

private func everyKind() -> IconDocument {
    var text = Layer(name: "Label", content: .text(TextContent(string: "Projects\nArchive", fontFamily: "Helvetica Neue", weight: .semibold, size: 0.1, tracking: 0.05,
                                                              fill: .linear(stops: [.init(color: .white, location: 0), .init(color: .black, location: 1)], angle: 45))))
    text.effects = [.outline(.init(color: .black, width: 0.01)), .dropShadow(.init(color: .black, dx: 0.01, dy: 0.02, blur: 0.03)),
                    .innerShadow(.init(enabled: false, color: .white, dx: 0, dy: 0.01, blur: 0.01)), .outerGlow(.init(color: .white, blur: 0.04, spread: 0.01)),
                    .innerGlow(.init(color: .white, blur: 0.02))]
    text.hideBelowSize = 32; text.blendMode = .softLight; text.locked = true; text.transform = LayerTransform(x: 0.4, y: 0.6, scale: 1.2, rotation: -12, flipY: true)
    var image = Layer(name: "Photo", content: .image(ImageContent(asset: "abc.jpg", size: .init(width: 0.8, height: 0.6), fit: .crop, crop: .init(x: 0.1, y: 0.2, width: 0.5, height: 0.375),
                                                                  adjust: .init(hue: 30, saturation: 0.5, brightness: -0.1, blur: 0.01, colorize: .init(color: .red, intensity: 0.4)))))
    image.clipToFolder = true; image.opacity = 0.7; image.visible = false
    return IconDocument(layers: [Layer(name: "Folder", content: .folderBase(FolderBase(style: .color, color: .init(r: 0.2, g: 0.6, b: 0.3)))), image, text,
                                 Layer(name: "Tree", content: .emoji(EmojiContent(character: "🌲", size: 0.25)))])
}

@Test func roundTripsEveryContentKindAndEffect() throws {
    let document = everyKind()
    #expect(try IconDocument.decode(document.encoded()) == document)
    let package = DocumentPackage(document: IconFixtures.package(named: "six-layers")!.document)
    #expect(try IconDocument.decode(package.document.encoded()) == package.document)
}

@Test func decodesGoldenJSON() throws {
    let json = """
    { "format": 1, "id": "6F1C2D3E-0000-4000-8000-000000000001", "layers": [
      { "id": "6F1C2D3E-0000-4000-8000-000000000002", "name": "Folder", "visible": true, "locked": false, "opacity": 1, "blendMode": "normal",
        "transform": { "x": 0.5, "y": 0.5, "scale": 1, "rotation": 0, "flipX": false, "flipY": false },
        "clipToFolder": false, "hideBelowSize": null, "effects": [],
        "content": { "type": "folderBase", "style": "color", "color": { "r": 0.2, "g": 0.6, "b": 0.3, "a": 1 } } },
      { "id": "6F1C2D3E-0000-4000-8000-000000000003", "name": "Photo", "visible": true, "locked": false, "opacity": 1, "blendMode": "multiply",
        "transform": { "x": 0.5, "y": 0.5, "scale": 1, "rotation": 0, "flipX": false, "flipY": false }, "clipToFolder": true, "hideBelowSize": null, "effects": [],
        "content": { "type": "image", "asset": "3f2ae1.jpg", "size": { "width": 0.8, "height": 0.6 },
        "fit": "fill", "crop": null, "adjust": { "hue": 0, "saturation": 1, "brightness": 0, "blur": 0, "colorize": null } } },
      { "id": "6F1C2D3E-0000-4000-8000-000000000004", "name": "Label", "visible": true, "locked": false, "opacity": 1, "blendMode": "normal",
        "transform": { "x": 0.5, "y": 0.62, "scale": 1, "rotation": 0, "flipX": false, "flipY": false }, "clipToFolder": false, "hideBelowSize": 32,
        "effects": [ { "type": "outline", "enabled": true, "color": { "r": 0, "g": 0, "b": 0, "a": 1 }, "width": 0.01 } ],
        "content": { "type": "text", "string": "Projects", "fontFamily": null, "weight": "bold", "size": 0.12,
        "tracking": 0, "fill": { "solid": { "r": 1, "g": 1, "b": 1, "a": 1 } } } },
      { "id": "6F1C2D3E-0000-4000-8000-000000000005", "name": "Tree", "visible": true, "locked": false, "opacity": 0.5, "blendMode": "normal",
        "transform": { "x": 0.75, "y": 0.25, "scale": 1, "rotation": 45, "flipX": false, "flipY": false }, "clipToFolder": false, "hideBelowSize": null, "effects": [],
        "content": { "type": "emoji", "character": "🌲", "size": 0.3 } } ] }
    """
    let document = try IconDocument.decode(Data(json.utf8))
    #expect(document.layers.map(\.name) == ["Folder", "Photo", "Label", "Tree"])
    #expect(document.layers[0].content == .folderBase(FolderBase(style: .color, color: RGBAColor(r: 0.2, g: 0.6, b: 0.3))))
    #expect(document.layers[1].content == .image(ImageContent(asset: "3f2ae1.jpg", size: CanvasSize(width: 0.8, height: 0.6))))
    #expect(document.layers[1].blendMode == .multiply && document.layers[1].clipToFolder)
    #expect(document.layers[2].content == .text(TextContent(string: "Projects", weight: .bold, size: 0.12, fill: .solid(.white))))
    #expect(document.layers[2].hideBelowSize == 32 && document.layers[2].effects == [.outline(.init(color: .black, width: 0.01))])
    #expect(document.layers[3].content == .emoji(EmojiContent(character: "🌲", size: 0.3)))
    #expect(document.layers[3].transform == LayerTransform(x: 0.75, y: 0.25, rotation: 45) && document.layers[3].opacity == 0.5)
    #expect(try IconDocument.decode(document.encoded()) == document)
}

@Test func encodesTypeDiscriminatorNextToPayload() throws {
    let json = try #require(String(data: everyKind().encoded(), encoding: .utf8))
    #expect(json.contains("\"type\" : \"folderBase\"") && json.contains("\"type\" : \"innerGlow\"") && json.contains("\"format\" : 1"))
}

@Test func rejectsNewerFormatUnknownTypesAndSecondFolderBase() throws {
    func decode(_ json: String) throws { _ = try IconDocument.decode(Data(json.utf8)) }
    let layer = { (content: String) in "{ \"id\": \"\(UUID())\", \"name\": \"L\", \"content\": \(content) }" }
    #expect(throws: DocumentError.unsupportedFormat(2)) { try decode("{ \"format\": 2, \"id\": \"\(UUID())\", \"layers\": [] }") }
    #expect(throws: DocumentError.unknownLayerType("hologram")) { try decode("{ \"format\": 1, \"id\": \"\(UUID())\", \"layers\": [\(layer("{ \"type\": \"hologram\" }"))] }") }
    let base = layer("{ \"type\": \"folderBase\", \"style\": \"system\", \"color\": { \"r\": 0, \"g\": 0, \"b\": 0, \"a\": 1 } }")
    #expect(throws: DocumentError.multipleFolderBases) { try decode("{ \"format\": 1, \"id\": \"\(UUID())\", \"layers\": [\(base), \(base)] }") }
}

@Test func missingLayerPropertiesFallBackToDefaults() throws {
    let json = "{ \"format\": 1, \"id\": \"\(UUID())\", \"layers\": [ { \"id\": \"\(UUID())\", \"name\": \"Tree\", \"content\": { \"type\": \"emoji\", \"character\": \"🌲\", \"size\": 0.3 } } ] }"
    let layer = try #require(IconDocument.decode(Data(json.utf8)).layers.first)
    #expect(layer.visible && !layer.locked && layer.opacity == 1 && layer.blendMode == .normal && layer.transform == LayerTransform() && layer.effects.isEmpty)
}

@Test func editingMovesDuplicatesAndRemovesLayers() throws {
    var document = everyKind()
    let ids = document.layers.map(\.id)
    document.move(fromOffsets: [3], toOffset: 1)
    #expect(document.layers.map(\.id) == [ids[0], ids[3], ids[1], ids[2]])
    document.move(fromOffsets: [1, 2], toOffset: 4)
    #expect(document.layers.map(\.id) == [ids[0], ids[2], ids[3], ids[1]])
    let refused = document.duplicate(ids[0]), duplicated = document.duplicate(ids[2])
    #expect(refused == nil)
    let copy = try #require(duplicated)
    #expect(document.layers[2].id == copy && document.layers[2].name == "Label copy" && document.layers[2].content == document.layers[1].content)
    document.remove(copy); document.remove(ids[3])
    #expect(document.layers.map(\.id) == [ids[0], ids[2], ids[1]])
    #expect(IconDocument.newDocument().layers.map(\.name) == ["Folder"] && IconDocument.newDocument().hasFolderBase)
}

@Test(arguments: [("🌲", true), ("👍🏽", true), ("🇩🇪", true), ("A", false), ("#", false), ("🌲🌲", false), ("", false)])
func emojiAcceptsOneEmojiGrapheme(input: String, accepted: Bool) {
    #expect(EmojiContent.accepts(input) == accepted)
}
