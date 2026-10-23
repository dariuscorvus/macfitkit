import AppKit
import FolderIconerCore
import SwiftUI

/// The 512 pt editing canvas: the rendered document, the selection box and its handles.
struct CanvasView: View {
    let model: EditorModel
    @Environment(ApplyController.self) private var applying
    @State private var drag: DragState?
    @State private var missed = false
    @FocusState private var focused: Bool
    private static let handleRadius: CGFloat = 7, rotateOffset: CGFloat = 20

    struct DragState { let id: Layer.ID; let handle: Handle; let start: LayerTransform; let startPoint: CGPoint; let size: CGSize }

    var body: some View {
        GeometryReader { proxy in
            let side = max(64, min(proxy.size.width, proxy.size.height, CGFloat(EditorModel.canvasPoints)))
            ZStack {
                Checkerboard()
                if let image = model.canvasImage { Image(decorative: image, scale: 2).resizable().interpolation(.high) }
                if let id = model.editingText, let layer = model.document[layer: id] {
                    CanvasTextEditor(model: model, layer: layer, contentSize: model.contentSize(of: layer), side: side)
                } else if let layer = model.selectedLayer, layer.visible { SelectionOverlay(layer: layer, size: model.contentSize(of: layer), side: side) }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { changed($0, side: side) }.onEnded { _ in ended() })
            .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { doubleClicked(at: $0.location, side: side) })
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .focusable().focused($focused).focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            guard model.selectedLayer?.locked == false else { return .ignored }
            let (dx, dy) = switch press.key { case .upArrow: (0, -1); case .downArrow: (0, 1); case .leftArrow: (-1, 0); default: (1, 0) }
            model.nudge(dx: dx, dy: dy, large: press.modifiers.contains(.shift)); return .handled
        }
        .onDeleteCommand { model.deleteSelection() }
        .dropDestination(for: URL.self) { urls, _ in applying.drop(urls) }
        .accessibilityLabel(Text("Canvas"))
    }

    private func changed(_ value: DragGesture.Value, side: CGFloat) {
        let point = CGPoint(x: value.location.x / side, y: value.location.y / side)
        if drag == nil && !missed { began(at: CGPoint(x: value.startLocation.x / side, y: value.startLocation.y / side), side: side) }
        guard let drag else { return }
        model.interact { document in
            document[layer: drag.id]?.transform = CanvasGeometry.drag(drag.handle, from: drag.start, startPoint: drag.startPoint, to: point, contentSize: drag.size,
                                                                     snapRotation: NSEvent.modifierFlags.contains(.shift))
        }
    }

    /// The selected layer's handles win; otherwise the topmost layer under the pointer is selected and moved.
    private func began(at point: CGPoint, side: CGFloat) {
        // A click outside the inline editor commits it before anything else happens.
        model.endTextEditing(); focused = true
        let tolerance = Self.handleRadius / side, offset = Self.rotateOffset / side
        var target: (Layer, Handle)?
        if let layer = model.selectedLayer, layer.visible,
           let handle = CanvasGeometry.handle(at: point, layer: layer, contentSize: model.contentSize(of: layer), tolerance: tolerance, rotateOffset: offset) {
            target = (layer, handle)
        } else if let id = CanvasGeometry.hitTest(point, layers: model.document.layers, sizes: model.contentSizes()), let layer = model.document[layer: id] {
            model.selection = id; target = (layer, .body)
        }
        guard let (layer, handle) = target else { model.selection = nil; missed = true; return }
        drag = DragState(id: layer.id, handle: handle, start: layer.transform, startPoint: point, size: model.contentSize(of: layer))
        model.beginInteraction()
    }

    private func doubleClicked(at location: CGPoint, side: CGFloat) {
        let point = CGPoint(x: location.x / side, y: location.y / side)
        if let id = CanvasGeometry.hitTest(point, layers: model.document.layers, sizes: model.contentSizes()) { model.editInPlace(id) }
    }

    private func ended() {
        if let drag {
            switch drag.handle {
            case .body: model.endInteraction("Move Layer")
            case .corner: model.endInteraction("Scale Layer")
            case .rotate: model.endInteraction("Rotate Layer")
            }
        }
        drag = nil; missed = false
    }
}

/// Outline, four corner handles and the rotate handle, drawn from `CanvasGeometry` in view points.
struct SelectionOverlay: View {
    let layer: Layer, size: CGSize, side: CGFloat

    var body: some View {
        let corners = CanvasGeometry.corners(layer, contentSize: size).map { CGPoint(x: $0.x * side, y: $0.y * side) }
        let rotate = CanvasGeometry.rotateHandle(layer, contentSize: size, offset: 20 / side)
        let rotatePoint = CGPoint(x: rotate.x * side, y: rotate.y * side)
        let topMiddle = CGPoint(x: (corners[0].x + corners[1].x) / 2, y: (corners[0].y + corners[1].y) / 2)
        ZStack {
            Path { $0.addLines(corners); $0.closeSubpath() }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: layer.locked ? [4, 3] : []))
            if !layer.locked {
                Path { $0.move(to: topMiddle); $0.addLine(to: rotatePoint) }.stroke(Color.accentColor, lineWidth: 1)
                ForEach(corners.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2).fill(.white).overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 1.5))
                        .frame(width: 9, height: 9).position(corners[index])
                }
                Circle().fill(.white).overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5)).frame(width: 10, height: 10).position(rotatePoint)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Transparency checkerboard behind the canvas.
struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 16
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.96)))
            for row in 0..<Int((size.height / cell).rounded(.up)) {
                for column in 0..<Int((size.width / cell).rounded(.up)) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(Color(white: 0.86)))
                }
            }
        }
    }
}
