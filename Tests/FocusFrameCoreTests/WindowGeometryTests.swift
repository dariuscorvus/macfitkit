import XCTest
@testable import FocusFrameCore

final class WindowGeometryTests: XCTestCase {
    func testMainDisplayConversion() {
        XCTAssertEqual(WindowGeometry.appKitRect(position: CGPoint(x: 100, y: 50),
            size: CGSize(width: 800, height: 600), mainDisplayTop: 900),
            CGRect(x: 100, y: 250, width: 800, height: 600))
    }

    func testDisplaysLeftAboveAndBelowMain() {
        for (position, expectedY) in [(CGPoint(x: -1200, y: 100), 500.0),
                                     (CGPoint(x: 100, y: -800), 1400.0),
                                     (CGPoint(x: 100, y: 1100), -500.0)] {
            let rect = WindowGeometry.appKitRect(position: position,
                size: CGSize(width: 600, height: 300), mainDisplayTop: 900)
            XCTAssertEqual(rect?.origin.x, position.x)
            XCTAssertEqual(rect?.origin.y, expectedY)
        }
    }

    func testInvalidGeometryIsRejected() {
        XCTAssertNil(WindowGeometry.appKitRect(position: .zero, size: .zero, mainDisplayTop: 900))
        XCTAssertNil(WindowGeometry.appKitRect(position: CGPoint(x: CGFloat.nan, y: 0),
            size: CGSize(width: 100, height: 100), mainDisplayTop: 900))
        XCTAssertNil(WindowGeometry.appKitRect(position: .zero,
            size: CGSize(width: -1, height: 100), mainDisplayTop: 900))
    }

    func testBorderGrowsOutward() {
        XCTAssertEqual(WindowGeometry.overlayRect(for: CGRect(x: -100, y: 50, width: 800, height: 600), width: 4),
            CGRect(x: -104, y: 46, width: 808, height: 608))
    }
}
