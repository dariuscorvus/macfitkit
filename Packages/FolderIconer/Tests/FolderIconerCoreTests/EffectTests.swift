import CoreGraphics
import Foundation
import Testing
@testable import FolderIconerCore

/// A white 0.4 × 0.4 square in the middle of an otherwise empty canvas.
private func square(_ effects: [LayerEffect], base: FolderBase.Style = .none, clip: Bool = false) -> DocumentPackage {
    var layer = Layer(name: "Square", content: .shape(ShapeContent(kind: .rectangle, size: CanvasSize(width: 0.4, height: 0.4))))
    layer.effects = effects; layer.clipToFolder = clip
    return DocumentPackage(document: IconDocument(layers: [Layer(name: "Folder", content: .folderBase(FolderBase(style: base))), layer]))
}

private func render(_ package: DocumentPackage, _ n: Int = 100) -> Pixels { Pixels(fixtureRenderer.render(package, points: n, scale: 1)) }

/// Columns/rows that hold any alpha above `threshold`.
private func bounds(_ pixels: Pixels, threshold: UInt8 = 8) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
    var box = (minX: Int.max, maxX: -1, minY: Int.max, maxY: -1)
    for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > threshold {
        box = (min(box.minX, x), max(box.maxX, x), min(box.minY, y), max(box.maxY, y))
    } }
    return box
}

@Test func outlineGrowsTheAlphaBoundsByItsWidth() {
    let plain = bounds(render(square([]))), outlined = bounds(render(square([.outline(.init(color: .black, width: 0.05))])))
    #expect(plain == (30, 69, 30, 69))
    for grown in [plain.minX - outlined.minX, outlined.maxX - plain.maxX, plain.minY - outlined.minY, outlined.maxY - plain.maxY] { #expect((4...6).contains(grown)) }
    #expect(render(square([.outline(.init(color: .black, width: 0.05))]))[27, 50] == [0, 0, 0, 255])
}

@Test func dropShadowToTheRightLeavesTheLeftSideEmpty() {
    let pixels = render(square([.dropShadow(.init(color: .black, dx: 0.1, dy: 0, blur: 0.01))]))
    #expect(pixels.alpha(75, 50) > 200 && pixels[75, 50][0] < 20)
    // Blur radius 1 px at 100 px: nothing beyond a few pixels left of the square.
    for y in 0..<100 { for x in 0..<26 { #expect(pixels.alpha(x, y) == 0) } }
    let box = bounds(pixels)
    #expect(box.minX >= 27 && box.maxX >= 78 && box.minY >= 26 && box.maxY <= 73)
}

@Test(arguments: [LayerEffect.innerShadow(.init(color: .black, dx: 0.05, dy: 0.05, blur: 0.03)), .innerGlow(.init(color: .red, blur: 0.05))])
func innerEffectsNeverAddAlphaOutsideTheContent(effect: LayerEffect) {
    let plain = render(square([])), effected = render(square([effect]))
    var changedInside = 0
    for y in 0..<100 { for x in 0..<100 {
        if plain.alpha(x, y) == 0 { #expect(effected.alpha(x, y) == 0) }
        if plain[x, y] != effected[x, y] { changedInside += 1 }
    } }
    #expect(changedInside > 200)
}

@Test func disabledOrZeroSizedEffectsMatchNoEffectsByteForByte() {
    let none = Bitmap.rgba(fixtureRenderer.render(square([], base: .system), points: 64, scale: 2))
    let disabled: [LayerEffect] = [.outline(.init(enabled: false, color: .black, width: 0.05)), .dropShadow(.init(enabled: false, color: .black, dx: 0.1, dy: 0.1, blur: 0.02)),
                                   .innerShadow(.init(enabled: false, color: .black, dx: 0.1, dy: 0.1, blur: 0.02)), .outerGlow(.init(enabled: false, color: .white, blur: 0.05)),
                                   .innerGlow(.init(enabled: false, color: .white, blur: 0.05))]
    let zero: [LayerEffect] = [.outline(.init(color: .black, width: 0)), .dropShadow(.init(color: .black, dx: 0, dy: 0, blur: 0)), .innerGlow(.init(color: .white, blur: 0))]
    #expect(Bitmap.rgba(fixtureRenderer.render(square(disabled, base: .system), points: 64, scale: 2)) == none)
    #expect(Bitmap.rgba(fixtureRenderer.render(square(zero, base: .system), points: 64, scale: 2)) == none)
}

@Test func arrayOrderDoesNotChangeTheRender() {
    let effects: [LayerEffect] = [.innerGlow(.init(color: .red, blur: 0.02)), .outline(.init(color: .black, width: 0.02)), .dropShadow(.init(color: .black, dx: 0.03, dy: 0.03, blur: 0.02)),
                                  .outerGlow(.init(color: .white, blur: 0.03, spread: 0.01)), .innerShadow(.init(color: .black, dx: 0.01, dy: 0.01, blur: 0.01))]
    #expect(render(square(effects)).bytes == render(square(effects.reversed())).bytes)
    #expect(EffectRenderer.ordered(effects).map(\.typeName) == ["dropShadow", "outerGlow", "outline", "innerShadow", "innerGlow"])
}

@Test func folderClipAlsoClipsTheShadow() {
    var package = square([.dropShadow(.init(color: .black, dx: 0, dy: 0.3, blur: 0.02)), .outerGlow(.init(color: .black, blur: 0.05, spread: 0.3))], clip: true)
    package.document.layers[1].transform.y = 0.8
    let rendered = render(package, 128), folder = Pixels(FixtureFolderShape().folderImage(pixels: 128))
    var outside = 0
    for y in 0..<128 { for x in 0..<128 where folder.alpha(x, y) == 0 { outside += 1; #expect(rendered.alpha(x, y) == 0) } }
    #expect(outside > 1000)
}

@Test func effectsScaleWithTheOutputSize() {
    let effects: [LayerEffect] = [.outline(.init(color: .black, width: 0.04))]
    let small = bounds(render(square(effects), 100)), large = bounds(render(square(effects), 400))
    #expect(abs(Double(large.maxX - large.minX + 1) / Double(small.maxX - small.minX + 1) - 4) < 0.15)
}
