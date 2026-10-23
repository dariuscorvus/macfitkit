import AppKit
import Foundation
import Testing
@testable import FolderIconerCore

@Test func iconImageHasTenRepresentationsWithMatchingSizes() {
    let image = fixtureRenderer.iconImage(DocumentPackage())
    let reps = image.representations.sorted { $0.pixelsWide < $1.pixelsWide }
    #expect(reps.map(\.pixelsWide) == [16, 32, 32, 64, 128, 256, 256, 512, 512, 1024])
    #expect(Set(reps.map { "\($0.pixelsWide)/\(Int($0.size.width))" }) == Set(IconSize.iconset.map { "\($0.pixels)/\($0.points)" }))
}

@Test func hideBelowSizeSkipsLayerAtSmallSizes() {
    let hidden = package([(.red, { $0.hideBelowSize = 64 })]), plain = DocumentPackage()
    #expect(Bitmap.rgba(fixtureRenderer.render(hidden, points: 32, scale: 1)) == Bitmap.rgba(fixtureRenderer.render(plain, points: 32, scale: 1)))
    #expect(Bitmap.rgba(fixtureRenderer.render(hidden, points: 128, scale: 1)) != Bitmap.rgba(fixtureRenderer.render(plain, points: 128, scale: 1)))
}

@Test func clipToFolderLeavesNoAlphaOutsideTheFolder() {
    let rendered = Pixels(fixtureRenderer.render(package([(.red, { $0.clipToFolder = true })]), points: 128, scale: 1))
    let folder = Pixels(FixtureFolderShape().folderImage(pixels: 128))
    var outside = 0
    for y in 0..<128 { for x in 0..<128 where folder.alpha(x, y) == 0 { outside += 1; #expect(rendered.alpha(x, y) == 0) } }
    #expect(outside > 1000)
}

@Test func recolorKeepsAlphaHitsTargetHueAndKeepsShading() throws {
    let folder = FixtureFolderShape().folderImage(pixels: 256), target = RGBAColor(r: 0.2, g: 0.6, b: 0.3)
    let input = Pixels(folder), output = Pixels(FolderRecolor.apply(folder, color: target))
    var sum = [0.0, 0.0, 0.0], count = 0.0, samples: [(Double, Double)] = []
    for i in stride(from: 0, to: input.bytes.count, by: 4) {
        #expect(input.bytes[i + 3] == output.bytes[i + 3])
        guard output.bytes[i + 3] == 255 else { continue }
        for c in 0..<3 { sum[c] += Double(output.bytes[i + c]) / 255 }; count += 1
        if Int(count) % 30 == 0, samples.count < 1000 { samples.append((luma(input.bytes, i), luma(output.bytes, i))) }
    }
    let mean = NSColor(srgbRed: sum[0] / count, green: sum[1] / count, blue: sum[2] / count, alpha: 1)
    let goal = NSColor(srgbRed: target.r, green: target.g, blue: target.b, alpha: 1)
    #expect(abs(mean.hueComponent - goal.hueComponent) * 360 < 3)
    #expect(samples.count == 1000)
    #expect(spearman(samples) > 0.99)
}

private func luma(_ bytes: [UInt8], _ i: Int) -> Double { 0.2126 * Double(bytes[i]) + 0.7152 * Double(bytes[i + 1]) + 0.0722 * Double(bytes[i + 2]) }

private func spearman(_ pairs: [(Double, Double)]) -> Double {
    func ranks(_ values: [Double]) -> [Double] {
        let order = values.indices.sorted { values[$0] < values[$1] }
        var result = [Double](repeating: 0, count: values.count), i = 0
        while i < order.count {
            var j = i; while j + 1 < order.count, values[order[j + 1]] == values[order[i]] { j += 1 }
            for k in i...j { result[order[k]] = Double(i + j) / 2 }; i = j + 1
        }
        return result
    }
    let a = ranks(pairs.map(\.0)), b = ranks(pairs.map(\.1)), n = Double(pairs.count)
    let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
    let cov = zip(a, b).reduce(0) { $0 + ($1.0 - ma) * ($1.1 - mb) }
    return cov / (a.reduce(0) { $0 + pow($1 - ma, 2) }.squareRoot() * b.reduce(0) { $0 + pow($1 - mb, 2) }.squareRoot())
}

@Test func transformPlacesContentInTheTopRightQuadrant() throws {
    let doc = package(base: .none, [(.red, { $0.content = .image(ImageContent(asset: $0.content.assetIDs[0], size: CanvasSize(width: 0.2, height: 0.2))); $0.transform = LayerTransform(x: 0.75, y: 0.25) })])
    let pixels = Pixels(fixtureRenderer.render(doc, points: 100, scale: 1))
    #expect(pixels[75, 25] == [255, 0, 0, 255])
    #expect(pixels[25, 25][3] == 0 && pixels[75, 75][3] == 0 && pixels[25, 75][3] == 0)
}

@Test func rotationNinetyEqualsRotatedRender() throws {
    var doc = DocumentPackage(document: IconDocument(layers: []))
    let asset = doc.addAsset(IconFixtures.gradientPNG(), pathExtension: "png")
    doc.document.layers = [Layer(name: "Image", content: .image(ImageContent(asset: asset, size: CanvasSize(width: 0.5, height: 0.25), fit: .crop, crop: NormalizedRect(x: 0, y: 0.25, width: 1, height: 0.5))))]
    let upright = Pixels(fixtureRenderer.render(doc, points: 64, scale: 1))
    doc.document.layers[0].transform.rotation = 90
    let rotated = Pixels(fixtureRenderer.render(doc, points: 64, scale: 1))
    var compared = 0
    for y in 0..<64 { for x in 0..<64 {
        let expected = upright[y, 63 - x], actual = rotated[x, y]
        guard [expected[3], actual[3]].allSatisfy({ $0 == 0 || $0 == 255 }) else { continue }
        compared += 1; #expect(zip(expected, actual).allSatisfy { abs(Int($0) - Int($1)) <= 1 }, "\(x),\(y)")
    } }
    #expect(compared > 4000)
    #expect(rotated[32, 20][3] == 255 && rotated[20, 32][3] == 0)
}

@Test func opacityHalvesAlpha() {
    let pixels = Pixels(fixtureRenderer.render(package(base: .none, [(.red, { $0.opacity = 0.5 })]), points: 16, scale: 1))
    for y in 0..<16 { for x in 0..<16 { #expect((127...128).contains(pixels.alpha(x, y))) } }
}

@Test func multiplyWhiteOverRedStaysRed() {
    let pixels = Pixels(fixtureRenderer.render(package(base: .none, [(.red, { _ in }), (.white, { $0.blendMode = .multiply })]), points: 16, scale: 1))
    #expect(pixels[8, 8] == [255, 0, 0, 255])
}

@Test func textBoxGrowsWithLengthAndTracking() {
    let doc = DocumentPackage()
    func width(_ string: String, tracking: Double = 0) -> CGFloat {
        fixtureRenderer.contentSize(of: Layer(name: "T", content: .text(TextContent(string: string, tracking: tracking))), in: doc).width
    }
    #expect(width("Projects") > width("Pro"))
    #expect(width("Projects", tracking: 0.2) > width("Projects"))
    let twoLines = fixtureRenderer.contentSize(of: Layer(name: "T", content: .text(TextContent(string: "a\nb"))), in: doc)
    #expect(twoLines.height > fixtureRenderer.contentSize(of: Layer(name: "T", content: .text(TextContent(string: "a"))), in: doc).height * 1.8)
}

@Test func emojiAndTextRenderVisiblePixels() throws {
    for content in [LayerContent.emoji(EmojiContent(character: "🌲")), .text(TextContent(string: "Hi", size: 0.4, fill: .linear(stops: [.init(color: .red, location: 0), .init(color: .white, location: 1)], angle: 30)))] {
        let doc = DocumentPackage(document: IconDocument(layers: [Layer(name: "L", content: content)]))
        let pixels = Pixels(fixtureRenderer.render(doc, points: 64, scale: 1))
        #expect(stride(from: 3, to: pixels.bytes.count, by: 4).filter { pixels.bytes[$0] > 200 }.count > 100)
    }
}

@Test func viewAffineMatchesCanvasAffineFlipped() {
    let transform = LayerTransform(x: 0.3, y: 0.7, scale: 0.8, rotation: 33, flipX: true)
    let point = CGPoint(x: 0.2, y: 0.1)
    let canvas = point.applying(transform.affine(pixels: 100)), view = point.applying(transform.viewAffine(side: 100))
    #expect(abs(canvas.x - view.x) < 1e-9 && abs((100 - canvas.y) - view.y) < 1e-9)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["FOLDERICONER_PERF"] == "1"))
func sixLayerRenderStaysUnderBudget() throws {
    let package = try #require(IconFixtures.package(named: "six-layers")), renderer = IconRenderer()
    #expect(package.document.layers.count == 6)
    _ = renderer.render(package, points: 512, scale: 2)
    let clock = ContinuousClock()
    let canvas = (0..<10).map { _ in clock.measure { _ = renderer.render(package, points: 512, scale: 2) } }.sorted()
    let iconset = (0..<3).map { _ in clock.measure { _ = renderer.iconImage(package) } }.sorted()
    print("FolderIconer perf: 1024 px canvas median \(canvas[5]), min \(canvas[0]); full iconset median \(iconset[1])")
    #expect(canvas[5] < .milliseconds(150))
}
