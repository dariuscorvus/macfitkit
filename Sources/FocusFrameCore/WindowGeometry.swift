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

    public static func overlayRect(for window: CGRect, width: CGFloat) -> CGRect {
        window.insetBy(dx: -width, dy: -width)
    }
}
