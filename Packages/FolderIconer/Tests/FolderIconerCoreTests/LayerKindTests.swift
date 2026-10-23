import CoreGraphics
import Foundation
import Testing
@testable import FolderIconerCore

private func single(_ content: LayerContent, assets: [AssetID: Data] = [:]) -> DocumentPackage {
    DocumentPackage(document: IconDocument(layers: [Layer(name: "L", content: content)]), assets: assets)
}

private func opaqueCount(_ pixels: Pixels) -> Int { stride(from: 3, to: pixels.bytes.count, by: 4).filter { pixels.bytes[$0] > 200 }.count }

@Test func roundTripsSymbolVectorAndShapeLayers() throws {
    let document = IconDocument(layers: [
        Layer(name: "Star", content: .symbol(SymbolContent(name: "star.fill", size: 0.25, weight: .heavy, rendering: .palette, colors: [.white, .black]))),
        Layer(name: "Logo", content: .vector(VectorContent(asset: "ab12.svg", size: CanvasSize(width: 0.5, height: 0.3)))),
        Layer(name: "Card", content: .shape(ShapeContent(kind: .circle, cornerRadius: 0, fill: .linear(stops: [.init(color: .white, location: 0)], angle: 10), stroke: .init(color: .black, width: 0.01)))),
        Layer(name: "Plain", content: .shape(ShapeContent()))
    ])
    #expect(try IconDocument.decode(document.encoded()) == document)
    #expect(document.assetIDs == ["ab12.svg"])
    let json = try #require(String(data: document.encoded(), encoding: .utf8))
    #expect(json.contains("\"type\" : \"symbol\"") && json.contains("\"type\" : \"vector\"") && json.contains("\"type\" : \"shape\""))
}

@Test func vectorFormatFollowsTheAssetExtension() {
    #expect(VectorContent(asset: "a.svg").format == .svg && VectorContent(asset: "a.PDF").format == .pdf && VectorContent(asset: "a.png").format == nil)
}

@Test func svgProbeSucceedsOnThisSystem() { #expect(VectorSupport.svgAvailable) }

@Test func pdfRendersRedAtTheCentreAndKeepsItsAspect() throws {
    let pdf = IconFixtures.badgePDF(), id = "badge.pdf"
    #expect(VectorSupport.intrinsicSize(pdf, format: .pdf) == CGSize(width: 200, height: 100))
    let pixels = Pixels(fixtureRenderer.render(single(.vector(VectorContent(asset: id, size: CanvasSize(width: 0.8, height: 0.8))), assets: [id: pdf]), points: 100, scale: 1))
    #expect(pixels[50, 50] == [255, 0, 0, 255])
    // 2:1 page aspect-fit into 80 × 80: the page spans rows 30…69.
    #expect(pixels.alpha(50, 25) == 0 && pixels.alpha(50, 75) == 0 && pixels.alpha(14, 50) == 255)
}

@Test func svgRendersGradientMaskAndIgnoresDropShadowFilter() throws {
    let ring = Data(IconFixtures.ringSVG.utf8), shadowed = Data(IconFixtures.dropShadowSVG.utf8)
    let ringPixels = Pixels(fixtureRenderer.render(single(.vector(VectorContent(asset: "r.svg", size: CanvasSize(width: 1, height: 1))), assets: ["r.svg": ring]), points: 100, scale: 1))
    // The mask punches a hole between r = 24 and the triangle; the ring itself is opaque and runs from yellow (top left) to pink (bottom right).
    #expect(ringPixels.alpha(50, 30) == 0 && ringPixels.alpha(50, 10) == 255)
    #expect(ringPixels[20, 20][1] > ringPixels[80, 80][1] + 60)
    let shadowPixels = Pixels(fixtureRenderer.render(single(.vector(VectorContent(asset: "s.svg", size: CanvasSize(width: 1, height: 1))), assets: ["s.svg": shadowed]), points: 100, scale: 1))
    // feDropShadow would darken the area right of and below the square. AppKit leaves it empty.
    #expect(shadowPixels[50, 50] == [255, 255, 255, 255] && shadowPixels.alpha(79, 79) == 0)
    #expect(VectorSupport.intrinsicSize(Data("not svg".utf8), format: .svg) == nil)
}

@Test func circleCornersAreTransparentAndRoundedRadiusIsClamped() {
    let circle = Pixels(fixtureRenderer.render(single(.shape(ShapeContent(kind: .circle, size: CanvasSize(width: 1, height: 1)))), points: 100, scale: 1))
    #expect(circle.alpha(2, 2) == 0 && circle.alpha(97, 97) == 0 && circle[50, 50] == [255, 255, 255, 255] && circle.alpha(50, 1) == 255)
    let pill = ShapeDrawing.path(ShapeContent(size: CanvasSize(width: 0.6, height: 0.2), cornerRadius: 5))
    #expect(pill.boundingBox.size == CGSize(width: 0.6, height: 0.2))
    let stroked = Pixels(fixtureRenderer.render(single(.shape(ShapeContent(kind: .rectangle, size: CanvasSize(width: 0.5, height: 0.5), fill: .solid(.white), stroke: .init(color: .black, width: 0.04)))), points: 100, scale: 1))
    #expect(stroked[25, 50] == [0, 0, 0, 255] && stroked[50, 50] == [255, 255, 255, 255] && stroked[23, 50] == [0, 0, 0, 255] && stroked.alpha(22, 50) == 0)
}

@Test func shapeGradientRunsAlongTheAngle() {
    let fill = Fill.linear(stops: [.init(color: .black, location: 0), .init(color: .white, location: 1)], angle: 0)
    let pixels = Pixels(fixtureRenderer.render(single(.shape(ShapeContent(kind: .rectangle, size: CanvasSize(width: 1, height: 1), fill: fill))), points: 100, scale: 1))
    #expect(pixels[2, 50][0] < 15 && pixels[97, 50][0] > 240 && abs(Int(pixels[50, 10][0]) - Int(pixels[50, 90][0])) <= 1)
}

@Test func symbolRendersAndUnknownNameRendersNothing() {
    #expect(SymbolDrawing.exists("star.fill") && !SymbolDrawing.exists("no.such.symbol.foldericoner"))
    let star = Pixels(fixtureRenderer.render(single(.symbol(SymbolContent(name: "star.fill", size: 0.5, colors: [.red]))), points: 100, scale: 1))
    #expect(opaqueCount(star) > 500 && star[50, 50] == [255, 0, 0, 255])
    let missing = Pixels(fixtureRenderer.render(single(.symbol(SymbolContent(name: "no.such.symbol.foldericoner"))), points: 100, scale: 1))
    #expect(missing.bytes.allSatisfy { $0 == 0 })
    let size = fixtureRenderer.contentSize(of: Layer(name: "S", content: .symbol(SymbolContent(name: "star.fill", size: 0.5))), in: DocumentPackage())
    #expect(size.width > 0.3 && size.width < 0.8 && size.height > 0.3 && size.height < 0.8)
}

@Test func symbolPaletteUsesBothColors() {
    let pixels = Pixels(fixtureRenderer.render(single(.symbol(SymbolContent(name: "star.circle.fill", size: 0.8, rendering: .palette, colors: [.white, .red]))), points: 100, scale: 1))
    #expect(pixels[50, 47] == [255, 255, 255, 255])
    #expect(pixels[50, 15] == [255, 0, 0, 255])
}
