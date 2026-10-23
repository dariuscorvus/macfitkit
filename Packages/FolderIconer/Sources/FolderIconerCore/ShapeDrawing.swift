import CoreGraphics

/// Rectangles, rounded rectangles and ellipses in canvas units, centred on the layer origin.
enum ShapeDrawing {
    static func path(_ shape: ShapeContent) -> CGPath {
        let box = CGSize(width: max(0, shape.size.width), height: max(0, shape.size.height)).centeredBox
        switch shape.kind {
        case .rectangle: return CGPath(rect: box, transform: nil)
        case .circle: return CGPath(ellipseIn: box, transform: nil)
        case .roundedRectangle:
            let radius = min(max(0, shape.cornerRadius), min(box.width, box.height) / 2)
            return CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
    }

    static func draw(_ shape: ShapeContent, in context: CGContext) {
        let path = path(shape)
        guard !path.boundingBox.isEmpty else { return }
        context.saveGState(); context.addPath(path); context.clip()
        FillPainter.paint(shape.fill, box: path.boundingBox, in: context); context.restoreGState()
        if let stroke = shape.stroke, stroke.width > 0 {
            context.addPath(path); context.setStrokeColor(stroke.color.cgColor); context.setLineWidth(stroke.width); context.strokePath()
        }
    }
}

/// Paints a `Fill` across `box` through the context's current clip. Shared by text and shapes.
enum FillPainter {
    static func paint(_ fill: Fill, box: CGRect, in context: CGContext) {
        switch fill {
        case .solid(let color): context.setFillColor(color.cgColor); context.fill(box)
        case .linear(let stops, let angle): linear(stops: stops, angle: angle, box: box, in: context)
        }
    }

    /// `angle`: degrees, clockwise on screen; the gradient spans the box's extent along that direction.
    static func linear(stops: [GradientStop], angle: Double, box: CGRect, in context: CGContext) {
        let sorted = stops.sorted { $0.location < $1.location }
        guard !sorted.isEmpty, let gradient = CGGradient(colorsSpace: Bitmap.sRGB, colors: sorted.map(\.color.cgColor) as CFArray, locations: sorted.map { CGFloat($0.location) }) else { return }
        let radians = angle * .pi / 180, direction = CGPoint(x: cos(radians), y: -sin(radians))
        let extent = abs(box.width / 2 * direction.x) + abs(box.height / 2 * direction.y)
        context.drawLinearGradient(gradient, start: CGPoint(x: box.midX - direction.x * extent, y: box.midY - direction.y * extent),
                                   end: CGPoint(x: box.midX + direction.x * extent, y: box.midY + direction.y * extent), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}
