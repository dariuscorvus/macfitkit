import CoreGraphics

/// Predict translation only after an AXMoved event confirms that this gesture
/// actually moves the window. Pointer deltas always use the original anchor.
public struct WindowDrag {
    private let initialFrame: CGRect
    private let initialPointer: CGPoint
    private var pointer: CGPoint
    public private(set) var isMoving = false

    public init(frame: CGRect, pointer: CGPoint) {
        initialFrame = frame
        initialPointer = pointer
        self.pointer = pointer
    }

    public mutating func updatePointer(_ point: CGPoint) -> CGRect? {
        pointer = point
        return predictedFrame
    }

    public mutating func confirmMove() -> CGRect? {
        isMoving = true
        return predictedFrame
    }

    public var predictedFrame: CGRect? {
        guard isMoving else { return nil }
        return initialFrame.offsetBy(dx: pointer.x - initialPointer.x,
                                     dy: pointer.y - initialPointer.y)
    }
}
