import Testing
import CoreGraphics
@testable import FocusFrameCore

struct WindowDragTests {
    private let frame = CGRect(x: -700, y: 500, width: 600, height: 400)

    @Test func contentGestureDoesNotMoveBorderWithoutWindowMoveConfirmation() {
        var drag = WindowDrag(frame: frame, pointer: CGPoint(x: -400, y: 880))
        #expect(drag.updatePointer(CGPoint(x: -200, y: 900)) == nil)
        #expect(!drag.isMoving)
    }

    @Test func firstWindowEventCatchesUpToLatestPointer() {
        var drag = WindowDrag(frame: frame, pointer: CGPoint(x: -400, y: 880))
        _ = drag.updatePointer(CGPoint(x: -200, y: 900))
        #expect(drag.confirmMove() == CGRect(x: -500, y: 520, width: 600, height: 400))
    }

    @Test func reversingDirectionReturnsToOriginalAnchorWithoutAccumulatedDrift() {
        let start = CGPoint(x: -400, y: 880)
        var drag = WindowDrag(frame: frame, pointer: start)
        _ = drag.confirmMove()
        _ = drag.updatePointer(CGPoint(x: 500, y: -200))
        #expect(drag.updatePointer(start) == frame)
        #expect(drag.updatePointer(CGPoint(x: -450, y: 850)) == CGRect(x: -750, y: 470, width: 600, height: 400))
    }

    @Test func repeatedWindowEventsDoNotReanchorToStaleGeometry() {
        var drag = WindowDrag(frame: frame, pointer: CGPoint(x: -400, y: 880))
        _ = drag.confirmMove()
        let current = drag.updatePointer(CGPoint(x: -200, y: 900))
        #expect(drag.confirmMove() == current)
    }
}
