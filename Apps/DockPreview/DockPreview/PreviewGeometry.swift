import Foundation
import CoreGraphics

/// Pure geometry shared by the Dock reader, panel positioning, and regression checks.
enum PreviewGeometry {
    enum Edge { case bottom, left, right }

    static func cocoaRect(fromAX rect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }

    static func edge(icon: CGRect, screen: CGRect) -> Edge {
        let distances: [(Edge, CGFloat)] = [
            (.bottom, abs(icon.minY - screen.minY)),
            (.left, abs(icon.minX - screen.minX)),
            (.right, abs(screen.maxX - icon.maxX))
        ]
        return distances.min { $0.1 < $1.1 }!.0
    }

    static func panelFrame(icon: CGRect, screen: CGRect, visible: CGRect, size: CGSize, edge: Edge? = nil) -> CGRect {
        let size = CGSize(width: min(size.width, visible.width - 16), height: min(size.height, visible.height - 16))
        let origin: CGPoint
        switch edge ?? self.edge(icon: icon, screen: screen) {
        case .bottom: origin = CGPoint(x: icon.midX - size.width / 2, y: icon.maxY + 8)
        case .left: origin = CGPoint(x: icon.maxX + 8, y: icon.midY - size.height / 2)
        case .right: origin = CGPoint(x: icon.minX - size.width - 8, y: icon.midY - size.height / 2)
        }
        return CGRect(x: min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8),
                      y: min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8),
                      width: size.width, height: size.height)
    }

    /// Narrow corridor from the icon to the panel; unrelated Dock icons remain hittable.
    static func bridge(icon: CGRect, panel: CGRect, edge: Edge) -> CGRect {
        switch edge {
        case .bottom:
            return CGRect(x: icon.minX - 5, y: icon.maxY - 2,
                          width: icon.width + 10, height: max(0, panel.minY - icon.maxY) + 4)
        case .left:
            return CGRect(x: icon.maxX - 2, y: icon.minY - 5,
                          width: max(0, panel.minX - icon.maxX) + 4, height: icon.height + 10)
        case .right:
            return CGRect(x: panel.maxX - 2, y: icon.minY - 5,
                          width: max(0, icon.minX - panel.maxX) + 4, height: icon.height + 10)
        }
    }
}

struct WindowDescriptor {
    let id: Int
    let title: String
    let frame: CGRect
}

enum WindowMatching {
    /// Never guess between indistinguishable windows. Selection keeps the original AX element.
    static func match(title: String, frame: CGRect, candidates: [WindowDescriptor]) -> Int? {
        let geometry = candidates.filter {
            abs($0.frame.minX - frame.minX) < 3 && abs($0.frame.minY - frame.minY) < 3 &&
            abs($0.frame.width - frame.width) < 3 && abs($0.frame.height - frame.height) < 3
        }
        let exact = geometry.filter { $0.title == title }
        if exact.count == 1 { return exact[0].id }
        if geometry.count == 1 { return geometry[0].id }
        let named = candidates.filter { !title.isEmpty && $0.title == title }
        return named.count == 1 ? named[0].id : nil
    }
}
