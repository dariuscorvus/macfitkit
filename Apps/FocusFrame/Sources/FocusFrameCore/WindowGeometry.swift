import Foundation
import CoreGraphics

public enum WindowGeometry {
    /// AX coordinates have their origin at the main display's upper-left corner.
    /// AppKit coordinates have their origin at that same display's lower-left.
    /// Use the main display's top edge, not the union of all attached displays.
    public static func appKitRect(position: CGPoint, size: CGSize, mainDisplayTop: CGFloat) -> CGRect? {
        guard position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite, mainDisplayTop.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(x: position.x, y: mainDisplayTop - position.y - size.height,
                      width: size.width, height: size.height)
    }

    public static func overlayRect(for window: CGRect, width: CGFloat, gap: CGFloat = 0) -> CGRect {
        window.insetBy(dx: -(width + gap), dy: -(width + gap))
    }
}

/// Front-to-back, public WindowServer metadata in AppKit screen coordinates.
public struct WindowStackEntry: Sendable {
    public var id: UInt32
    public var pid: Int32
    public var bounds: CGRect
    public init(id: UInt32, pid: Int32, bounds: CGRect) {
        self.id = id; self.pid = pid; self.bounds = bounds
    }
}

public enum WindowOcclusion {
    /// Equal-geometry windows of one process are ambiguous; never guess by order.
    public static func target(in stack: [WindowStackEntry], pid: Int32, bounds: CGRect,
                              knownID: UInt32? = nil) -> Int? {
        let matches = stack.indices.filter {
            let w = stack[$0]
            guard w.pid == pid else { return false }
            // Once resolved from AX geometry, the public window ID stays stable
            // while the same focused AX element moves/resizes asynchronously.
            if let knownID { return w.id == knownID }
            return abs(w.bounds.minX - bounds.minX) <= 1 && abs(w.bounds.minY - bounds.minY) <= 1 &&
                abs(w.bounds.width - bounds.width) <= 1 && abs(w.bounds.height - bounds.height) <= 1
        }
        return matches.count == 1 ? matches[0] : nil
    }

    /// Disjoint rectangles avoid even-odd holes reappearing where occluders overlap.
    public static func visibleRegions(in area: CGRect, coveredBy covers: [CGRect]) -> [CGRect] {
        guard !area.isEmpty, !area.isInfinite, !area.isNull else { return [] }
        return covers.reduce([area]) { regions, cover in
            regions.flatMap { rect -> [CGRect] in
                let cut = rect.intersection(cover)
                guard !cut.isNull, !cut.isEmpty else { return [rect] }
                return [
                    CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: cut.minY - rect.minY),
                    CGRect(x: rect.minX, y: cut.maxY, width: rect.width, height: rect.maxY - cut.maxY),
                    CGRect(x: rect.minX, y: cut.minY, width: cut.minX - rect.minX, height: cut.height),
                    CGRect(x: cut.maxX, y: cut.minY, width: rect.maxX - cut.maxX, height: cut.height)
                ].filter { !$0.isEmpty }
            }
        }
    }
}
