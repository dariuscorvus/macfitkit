import Foundation
import CoreGraphics

@main
struct PreviewCoreChecks {
    static func main() {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            guard value else { fatalError(message) }
            count += 1
        }
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 64, width: 1440, height: 811)
        let icon = CGRect(x: 700, y: 4, width: 48, height: 48)
        let bottom = PreviewGeometry.panelFrame(icon: icon, screen: primary, visible: visible,
                                                size: CGSize(width: 744, height: 250), edge: .bottom)
        check(visible.contains(bottom), "Bottom panel must fit usable screen")
        check(bottom.minY >= icon.maxY, "Bottom panel must sit above Dock")
        check(bottom.midX == 724, "Bottom panel must be centered at hovered icon")
        let narrow = PreviewGeometry.panelFrame(icon: icon, screen: primary, visible: visible,
                                                size: CGSize(width: 4000, height: 250), edge: .bottom)
        check(visible.contains(narrow), "Many windows must not overflow screen")
        let secondary = CGRect(x: -1280, y: -200, width: 1280, height: 1024)
        let leftIcon = CGRect(x: -1280, y: -180, width: 48, height: 48)
        let left = PreviewGeometry.panelFrame(icon: leftIcon, screen: secondary, visible: secondary,
                                              size: CGSize(width: 744, height: 250), edge: .left)
        check(secondary.contains(left), "Panel must stay on a left/below secondary screen")
        check(left.minX > leftIcon.maxX, "Explicit left Dock edge must win near bottom corner")
        let rightIcon = CGRect(x: 1388, y: 500, width: 48, height: 48)
        let right = PreviewGeometry.panelFrame(icon: rightIcon, screen: primary, visible: primary,
                                               size: CGSize(width: 744, height: 250), edge: .right)
        check(right.maxX < rightIcon.minX, "Right Dock panel must sit to the left")
        let corridor = PreviewGeometry.bridge(icon: icon, panel: bottom, edge: .bottom)
        check(corridor.contains(CGPoint(x: 724, y: 60)), "Pointer must cross gap without dismissal")
        check(!corridor.contains(CGPoint(x: 800, y: 30)), "Bridge must not swallow neighboring Dock icons")
        let converted = PreviewGeometry.cocoaRect(fromAX: CGRect(x: -1200, y: 1000, width: 48, height: 48), primaryTop: 900)
        check(converted == CGRect(x: -1200, y: -148, width: 48, height: 48), "AX coordinates must work below primary screen")
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let otherFrame = CGRect(x: 900, y: 20, width: 800, height: 600)
        let duplicateTitles = [WindowDescriptor(id: 1, title: "Untitled", frame: frame),
                               WindowDescriptor(id: 2, title: "Untitled", frame: otherFrame)]
        check(WindowMatching.match(title: "Untitled", frame: otherFrame, candidates: duplicateTitles) == 2,
              "Same titles must resolve by frame, not list order")
        let indistinguishable = [WindowDescriptor(id: 1, title: "Untitled", frame: frame),
                                  WindowDescriptor(id: 2, title: "Untitled", frame: frame)]
        check(WindowMatching.match(title: "Untitled", frame: frame, candidates: indistinguishable) == nil,
              "Ambiguous screenshots must stay unavailable")
        check(WindowMatching.match(title: "Moved", frame: frame,
                                   candidates: [WindowDescriptor(id: 3, title: "Moved", frame: otherFrame)]) == 3,
              "Unique window title can survive a moving window")
        check(WindowMatching.match(title: "Closed", frame: frame, candidates: []) == nil,
              "Closed windows must not acquire an unrelated thumbnail")
        check(WindowMatching.match(title: "", frame: frame,
                                   candidates: [WindowDescriptor(id: 4, title: "", frame: otherFrame)]) == nil,
              "Empty titles must not match unrelated geometry")
        check(WindowMatching.match(title: "Renamed", frame: frame,
                                   candidates: [WindowDescriptor(id: 5, title: "Old title", frame: frame)]) == 5,
              "A renamed window can retain its geometry match")
        print("\(count) preview geometry and window-matching checks passed.")
    }
}
