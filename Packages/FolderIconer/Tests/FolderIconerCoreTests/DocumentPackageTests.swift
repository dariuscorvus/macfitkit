import Foundation
import Testing
@testable import FolderIconerCore

@Test func writeThenReadReturnsTheSamePackage() throws {
    let root = temporaryDirectory("Package"); defer { try? FileManager.default.removeItem(at: root) }
    let original = try #require(IconFixtures.package(named: "six-layers")), url = root.appendingPathComponent("Six.foldericon")
    try original.write(to: url)
    #expect(try DocumentPackage.read(from: url) == original)
    try original.write(to: url)
    #expect(try FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent("assets").path).sorted() == original.assets.keys.sorted())
}

@Test func importingTheSameFileTwiceYieldsOneAsset() throws {
    let root = temporaryDirectory("Import"); defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let a = root.appendingPathComponent("a.PNG"), b = root.appendingPathComponent("b.png")
    try solidPNG(.red).write(to: a); try solidPNG(.red).write(to: b)
    var package = DocumentPackage()
    let first = try package.importAsset(from: a), second = try package.importAsset(from: b)
    #expect(first == second && package.assets.count == 1 && first.hasSuffix(".png") && first.count == 64 + 4)
}

@Test func writeDropsUnreferencedAssets() throws {
    let root = temporaryDirectory("Prune"); defer { try? FileManager.default.removeItem(at: root) }
    var package = package([(.red, { _ in })]); package.addAsset(solidPNG(.white), pathExtension: "png")
    #expect(package.assets.count == 2)
    let url = root.appendingPathComponent("Doc.foldericon"); try package.write(to: url)
    let read = try DocumentPackage.read(from: url)
    #expect(read.assets.count == 1 && read.assets.keys.first == package.document.assetIDs.first)
    #expect(try FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent("assets").path).count == 1)
}

@Test func renderKeepsImageAfterSourceIsDeleted() throws {
    let root = temporaryDirectory("Source"); defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("red.png"); try solidPNG(.red).write(to: source)
    var package = DocumentPackage(document: IconDocument(layers: []))
    let asset = try package.importAsset(from: source)
    package.document.layers = [Layer(name: "Red", content: .image(ImageContent(asset: asset)))]
    let url = root.appendingPathComponent("Doc.foldericon"); try package.write(to: url)
    try FileManager.default.removeItem(at: source)
    let pixels = Pixels(IconRenderer(options: .init(folder: FixtureFolderShape())).render(try DocumentPackage.read(from: url), points: 16, scale: 1))
    #expect(pixels[8, 8] == [255, 0, 0, 255])
}

@Test func failedWriteLeavesThePreviousPackage() throws {
    let root = temporaryDirectory("Atomic"); defer { try? FileManager.default.removeItem(at: root) }
    let original = package([(.red, { _ in })]), url = root.appendingPathComponent("Doc.foldericon")
    try original.write(to: url)
    var broken = original; broken.document.layers.append(Layer(name: "Missing", content: .image(ImageContent(asset: "deadbeef.png"))))
    #expect(throws: DocumentError.missingAsset("deadbeef.png")) { try broken.write(to: url) }
    #expect(try DocumentPackage.read(from: url) == original)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["Doc.foldericon"])
}
