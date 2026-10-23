import Foundation

/// One representation of a folder icon.
public struct IconSize: Hashable, Sendable, CustomStringConvertible {
    public var points: Int, scale: Int
    public init(points: Int, scale: Int) { self.points = points; self.scale = scale }
    public var pixels: Int { points * scale }
    public var description: String { "\(points)@\(scale)x" }
    /// 16…512 pt @1x/@2x: 10 entries, 16…1024 px.
    public static let iconset = [16, 32, 128, 256, 512].flatMap { points in [1, 2].map { IconSize(points: points, scale: $0) } }
}
