import Testing
import CoreGraphics
@testable import FocusFrameCore

struct WindowGeometryTests {
    @Test func mainDisplayConversion() {
        #expect(WindowGeometry.appKitRect(position: CGPoint(x: 100, y: 50),
            size: CGSize(width: 800, height: 600), mainDisplayTop: 900) ==
            CGRect(x: 100, y: 250, width: 800, height: 600))
    }

    @Test func displaysLeftAboveAndBelowMain() {
        for (position, expectedY) in [(CGPoint(x: -1200, y: 100), 500.0),
                                     (CGPoint(x: 100, y: -800), 1400.0),
                                     (CGPoint(x: 100, y: 1100), -500.0)] {
            let rect = WindowGeometry.appKitRect(position: position,
                size: CGSize(width: 600, height: 300), mainDisplayTop: 900)
            #expect(rect?.origin.x == position.x)
            #expect(rect?.origin.y == CGFloat(expectedY))
        }
    }

    @Test func invalidGeometryIsRejected() {
        #expect(WindowGeometry.appKitRect(position: .zero, size: .zero, mainDisplayTop: 900) == nil)
        #expect(WindowGeometry.appKitRect(position: CGPoint(x: CGFloat.nan, y: 0),
            size: CGSize(width: 100, height: 100), mainDisplayTop: 900) == nil)
        #expect(WindowGeometry.appKitRect(position: .zero,
            size: CGSize(width: -1, height: 100), mainDisplayTop: 900) == nil)
    }

    @Test func borderGrowsOutward() {
        #expect(WindowGeometry.overlayRect(for: CGRect(x: -100, y: 50, width: 800, height: 600), width: 4) ==
            CGRect(x: -104, y: 46, width: 808, height: 608))
    }
}
