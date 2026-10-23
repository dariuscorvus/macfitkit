import CoreGraphics
import Foundation
import Testing
@testable import FolderIconerCore

private func box(_ transform: LayerTransform, visible: Bool = true, locked: Bool = false) -> Layer {
    var layer = Layer(name: "Box", content: .emoji(EmojiContent(character: "🌲"))); layer.transform = transform; layer.visible = visible; layer.locked = locked
    return layer
}
private let size = CGSize(width: 0.4, height: 0.2)
private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }

@Test func hitTestRespectsRotation() {
    let layer = box(LayerTransform(rotation: 90)), sizes = [layer.id: size]
    // Rotated 90°, the 0.4 × 0.2 box spans 0.2 wide and 0.4 tall around the centre.
    #expect(CanvasGeometry.hitTest(CGPoint(x: 0.5, y: 0.68), layers: [layer], sizes: sizes) == layer.id)
    #expect(CanvasGeometry.hitTest(CGPoint(x: 0.68, y: 0.5), layers: [layer], sizes: sizes) == nil)
}

@Test func hitTestSkipsHiddenAndLockedAndPrefersTopmost() {
    let bottom = box(LayerTransform()), hidden = box(LayerTransform(), visible: false), locked = box(LayerTransform(), locked: true)
    let sizes = Dictionary(uniqueKeysWithValues: [bottom, hidden, locked].map { ($0.id, size) })
    #expect(CanvasGeometry.hitTest(CGPoint(x: 0.5, y: 0.5), layers: [bottom, hidden, locked], sizes: sizes) == bottom.id)
    let top = box(LayerTransform(x: 0.55))
    #expect(CanvasGeometry.hitTest(CGPoint(x: 0.5, y: 0.5), layers: [bottom, top], sizes: sizes.merging([top.id: size]) { $1 }) == top.id)
}

@Test func hitTestIsFlipAndScaleAware() {
    let layer = box(LayerTransform(scale: 2, flipX: true, flipY: true)), sizes = [layer.id: size]
    #expect(CanvasGeometry.hitTest(CGPoint(x: 0.89, y: 0.5), layers: [layer], sizes: sizes) == layer.id)
    #expect(CanvasGeometry.hitTest(CGPoint(x: 0.5, y: 0.71), layers: [layer], sizes: sizes) == nil)
    let local = CanvasGeometry.local(CGPoint(x: 0.6, y: 0.55), layer.transform)
    #expect(close(local.x, -0.05) && close(local.y, -0.025))
}

@Test func cornersAndHandlesFollowTheTransform() throws {
    let layer = box(LayerTransform(x: 0.5, y: 0.5, scale: 1, rotation: 90))
    let corners = CanvasGeometry.corners(layer, contentSize: size)
    // Top-left (−0.2, −0.1) turns clockwise to (0.1, −0.2).
    #expect(close(corners[0].x, 0.6) && close(corners[0].y, 0.3))
    let rotate = CanvasGeometry.rotateHandle(layer, contentSize: size, offset: 0.05)
    #expect(close(rotate.x, 0.65) && close(rotate.y, 0.5))
    #expect(CanvasGeometry.handle(at: CGPoint(x: 0.648, y: 0.5), layer: layer, contentSize: size, tolerance: 0.01, rotateOffset: 0.05) == .rotate)
    #expect(CanvasGeometry.handle(at: CGPoint(x: 0.605, y: 0.3), layer: layer, contentSize: size, tolerance: 0.01, rotateOffset: 0.05) == .corner(.topLeft))
    #expect(CanvasGeometry.handle(at: CGPoint(x: 0.5, y: 0.5), layer: layer, contentSize: size, tolerance: 0.01, rotateOffset: 0.05) == .body)
    #expect(CanvasGeometry.handle(at: CGPoint(x: 0.9, y: 0.9), layer: layer, contentSize: size, tolerance: 0.01, rotateOffset: 0.05) == nil)
    var locked = layer; locked.locked = true
    #expect(CanvasGeometry.handle(at: CGPoint(x: 0.5, y: 0.5), layer: locked, contentSize: size, tolerance: 0.01, rotateOffset: 0.05) == nil)
}

@Test func bodyDragMovesByTheDelta() {
    let start = LayerTransform(x: 0.3, y: 0.4, rotation: 20)
    let moved = CanvasGeometry.drag(.body, from: start, startPoint: CGPoint(x: 0.35, y: 0.45), to: CGPoint(x: 0.45, y: 0.4), contentSize: size, snapRotation: false)
    #expect(close(moved.x, 0.4) && close(moved.y, 0.35) && moved.rotation == 20 && moved.scale == 1)
}

@Test func cornerDragScalesByTheDistanceRatioAndClamps() {
    let start = LayerTransform(scale: 1.5, flipX: true)
    let doubled = CanvasGeometry.drag(.corner(.topRight), from: start, startPoint: CGPoint(x: 0.6, y: 0.5), to: CGPoint(x: 0.5, y: 0.7), contentSize: size, snapRotation: false)
    #expect(close(doubled.scale, 3) && doubled.flipX && doubled.x == 0.5)
    let tiny = CanvasGeometry.drag(.corner(.bottomLeft), from: start, startPoint: CGPoint(x: 0.6, y: 0.5), to: CGPoint(x: 0.5, y: 0.5), contentSize: size, snapRotation: false)
    #expect(tiny.scale == CanvasGeometry.minimumScale)
    let negative = CanvasGeometry.drag(.corner(.topLeft), from: LayerTransform(scale: -1), startPoint: CGPoint(x: 0.6, y: 0.5), to: CGPoint(x: 0.7, y: 0.5), contentSize: size, snapRotation: false)
    #expect(close(negative.scale, -2))
}

private func rotation(to degrees: Double, snap: Bool, from start: Double = 0) -> Double {
    let a = degrees * .pi / 180
    return CanvasGeometry.drag(.rotate, from: LayerTransform(rotation: start), startPoint: CGPoint(x: 0.8, y: 0.5),
                               to: CGPoint(x: 0.5 + 0.3 * cos(a), y: 0.5 + 0.3 * sin(a)), contentSize: size, snapRotation: snap).rotation
}

@Test func rotateDragTurnsClockwiseAndSnapsToFifteenDegrees() {
    #expect(close(rotation(to: 37, snap: false), 37))
    #expect(rotation(to: 37, snap: true) == 30)
    #expect(rotation(to: 38, snap: true) == 45)
    #expect(close(rotation(to: 30, snap: false, from: 170), -160))
    #expect(rotation(to: 0, snap: true, from: 180) == 180)
}

@Test(arguments: [(0.0, 0.0), (180, 180), (-180, 180), (190, -170), (-190, 170), (540, 180), (-30, -30), (720, 0)])
func normalisesToHalfOpenRange(input: Double, expected: Double) {
    #expect(close(CanvasGeometry.normalized(input), expected))
}

@Test func nudgeMovesOne512thAndTenTimesWithShift() {
    let small = CanvasGeometry.nudge(LayerTransform(), dx: 1, dy: -1, large: false)
    #expect(close(small.x, 0.5 + 1.0 / 512) && close(small.y, 0.5 - 1.0 / 512))
    let large = CanvasGeometry.nudge(LayerTransform(), dx: 0, dy: 1, large: true)
    #expect(large.x == 0.5 && close(large.y, 0.5 + 10.0 / 512))
}

@Test func displayedMoveMapsTopFirstOffsets() {
    let names = ["A", "B", "C", "D"]
    func moved(_ source: IndexSet, _ destination: Int) -> [String] {
        var document = IconDocument(layers: names.map { Layer(name: $0, content: .emoji(EmojiContent(character: "🌲"))) })
        document.moveDisplayed(fromOffsets: source, toOffset: destination); return document.layers.map(\.name)
    }
    // Display order is D C B A.
    #expect(moved([3], 0) == ["B", "C", "D", "A"])
    #expect(moved([0], 4) == ["D", "A", "B", "C"])
    #expect(moved([0, 1], 4) == ["C", "D", "A", "B"])
    #expect(moved([2], 2) == names)
}

@Test func textEditorBoxFollowsPositionScaleAndFontSize() {
    var layer = Layer(name: "Text", content: .text(TextContent(string: "Forest", size: 0.1))); layer.transform = LayerTransform(x: 0.25, y: 0.75, scale: -2)
    let box = CanvasGeometry.textEditorBox(layer, text: TextContent(string: "Forest", size: 0.1), contentSize: CGSize(width: 0.3, height: 0.12), side: 512)
    #expect(box.center == CGPoint(x: 128, y: 384))
    // Scale 2 (sign is a flip): 0.1 × 2 × 512 pt font, box 0.3 × 2 × 512 wide plus one em.
    #expect(close(box.fontPoints, 102.4) && close(box.size.width, 307.2 + 102.4) && close(box.size.height, 122.88))
}

@Test func textEditorBoxKeepsOneLineHeightForEmptyText() {
    let layer = Layer(name: "Text", content: .text(TextContent(string: "", size: 0.1)))
    let box = CanvasGeometry.textEditorBox(layer, text: TextContent(string: "", size: 0.1), contentSize: .zero, side: 512)
    #expect(close(box.size.width, 51.2) && close(box.size.height, 51.2))
}

@Test(arguments: [("New", "Old", "New"), ("", "Old", "Old"), (" \n", "Old", "Old"), ("Two\nLines", "Old", "Two\nLines")])
func committedTextFallsBackOnlyWhenEmpty(edited: String, original: String, expected: String) {
    #expect(CanvasGeometry.committedText(edited, original: original) == expected)
}
