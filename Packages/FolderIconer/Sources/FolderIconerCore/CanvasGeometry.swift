import CoreGraphics
import Foundation

/// What a canvas drag grabs: the layer itself, one of its corners (uniform scale) or the rotate handle.
public enum Handle: Hashable, Sendable {
    public enum Corner: Int, CaseIterable, Sendable { case topLeft, topRight, bottomRight, bottomLeft }
    case body, corner(Corner), rotate
}

/// Editor hit testing and drag math. Canvas units, origin top-left, y down; rotation positive clockwise on screen.
public enum CanvasGeometry {
    public static let minimumScale = 0.02, maximumScale = 20.0, snapDegrees = 15.0, nudgeStep = 1.0 / 512

    /// The four corners of the transformed content box, in `Handle.Corner` order (before flips).
    public static func corners(_ layer: Layer, contentSize: CGSize) -> [CGPoint] {
        let t = layer.transform, s = abs(t.scale), w = contentSize.width * s / 2, h = contentSize.height * s / 2
        return [CGPoint(x: -w, y: -h), CGPoint(x: w, y: -h), CGPoint(x: w, y: h), CGPoint(x: -w, y: h)].map { toCanvas($0, t) }
    }

    /// Where the rotate handle sits: `offset` canvas units above the middle of the top edge, rotated with the layer.
    public static func rotateHandle(_ layer: Layer, contentSize: CGSize, offset: Double) -> CGPoint {
        toCanvas(CGPoint(x: 0, y: -contentSize.height * abs(layer.transform.scale) / 2 - offset), layer.transform)
    }

    /// `p` in the layer's local content box, scale and flips removed (centred at the origin, y down).
    public static func local(_ p: CGPoint, _ t: LayerTransform) -> CGPoint {
        let r = rotated(CGPoint(x: p.x - t.x, y: p.y - t.y), by: -t.rotation), s = max(abs(t.scale), 1e-9)
        return CGPoint(x: r.x / (s * (t.flipX ? -1 : 1)), y: r.y / (s * (t.flipY ? -1 : 1)))
    }

    public static func contains(_ p: CGPoint, layer: Layer, contentSize: CGSize) -> Bool {
        let q = local(p, layer.transform)
        return abs(q.x) <= contentSize.width / 2 && abs(q.y) <= contentSize.height / 2
    }

    /// The topmost visible, unlocked layer under `p`. Layers are bottom → top.
    public static func hitTest(_ p: CGPoint, layers: [Layer], sizes: [UUID: CGSize]) -> UUID? {
        layers.reversed().first { layer in
            guard layer.visible, !layer.locked, let size = sizes[layer.id] else { return false }
            return contains(p, layer: layer, contentSize: size)
        }?.id
    }

    /// The handle of an unlocked layer under `p`. The rotate handle wins over corners, corners over the body.
    public static func handle(at p: CGPoint, layer: Layer, contentSize: CGSize, tolerance: Double, rotateOffset: Double) -> Handle? {
        guard !layer.locked else { return nil }
        if distance(p, rotateHandle(layer, contentSize: contentSize, offset: rotateOffset)) <= tolerance { return .rotate }
        for (corner, point) in zip(Handle.Corner.allCases, corners(layer, contentSize: contentSize)) where distance(p, point) <= tolerance { return .corner(corner) }
        return contains(p, layer: layer, contentSize: contentSize) ? .body : nil
    }

    /// The transform after dragging `handle` from `startPoint` to `p`, starting from `start`.
    public static func drag(_ handle: Handle, from start: LayerTransform, startPoint: CGPoint, to p: CGPoint, contentSize: CGSize, snapRotation: Bool) -> LayerTransform {
        var t = start
        let c = CGPoint(x: start.x, y: start.y)
        switch handle {
        case .body: t.x = start.x + p.x - startPoint.x; t.y = start.y + p.y - startPoint.y
        case .corner:
            let from = distance(startPoint, c)
            guard from > 1e-9 else { return start }
            let scale = min(max(abs(start.scale) * distance(p, c) / from, minimumScale), maximumScale)
            t.scale = start.scale < 0 ? -scale : scale
        case .rotate:
            let delta = (atan2(p.y - c.y, p.x - c.x) - atan2(startPoint.y - c.y, startPoint.x - c.x)) * 180 / .pi
            t.rotation = normalized(start.rotation + delta)
            if snapRotation { t.rotation = normalized((t.rotation / snapDegrees).rounded() * snapDegrees) }
        }
        return t
    }

    /// Arrow-key move: 1/512 of the canvas per press, ten times that with `large` (Shift).
    public static func nudge(_ t: LayerTransform, dx: Int, dy: Int, large: Bool) -> LayerTransform {
        var t = t; let step = nudgeStep * (large ? 10 : 1)
        t.x += Double(dx) * step; t.y += Double(dy) * step; return t
    }

    /// Degrees in (−180, 180].
    public static func normalized(_ degrees: Double) -> Double {
        let r = (degrees + 180).truncatingRemainder(dividingBy: 360)
        let value = (r <= 0 ? r + 360 : r) - 180
        return abs(value) < 1e-9 ? 0 : value
    }

    /// Where the inline text editor sits on a `side`-point canvas: centre, unrotated box and font size, all in view points.
    /// The box gets one em of extra width so the next typed character fits before the layout catches up.
    public static func textEditorBox(_ layer: Layer, text: TextContent, contentSize: CGSize, side: Double) -> (center: CGPoint, size: CGSize, fontPoints: Double) {
        let s = abs(layer.transform.scale) * side, points = text.size * s
        return (CGPoint(x: layer.transform.x * side, y: layer.transform.y * side), CGSize(width: contentSize.width * s + points, height: max(contentSize.height * s, points)), points)
    }

    /// The text a finished inline edit leaves: empty text would leave an invisible layer that can't be hit, so it falls back to `original`.
    public static func committedText(_ edited: String, original: String) -> String {
        edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? original : edited
    }

    static func toCanvas(_ v: CGPoint, _ t: LayerTransform) -> CGPoint {
        let r = rotated(v, by: t.rotation); return CGPoint(x: t.x + r.x, y: t.y + r.y)
    }

    /// Positive degrees turn clockwise in y-down coordinates.
    static func rotated(_ v: CGPoint, by degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: v.x * cos(a) - v.y * sin(a), y: v.x * sin(a) + v.y * cos(a))
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
}

public extension IconDocument {
    /// `move(fromOffsets:toOffset:)` for a list that shows the top layer first.
    mutating func moveDisplayed(fromOffsets source: IndexSet, toOffset destination: Int) {
        let count = layers.count
        move(fromOffsets: IndexSet(source.map { count - 1 - $0 }), toOffset: count - destination)
    }
}
