import CoreGraphics

/// Rectangles, rounded rectangles and ellipses in canvas units, centred on the layer origin.
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
