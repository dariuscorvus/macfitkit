import CoreGraphics
import Foundation
import Testing
@testable import FolderIconerCore

/// References were recorded on macOS 27.2 with `FixtureFolderShape`. Text antialiasing and emoji bitmaps change between OS
/// releases, so re-record (`FOLDERICONER_RECORD_SNAPSHOTS=1`) in a separate commit after an OS update.
enum Snapshot {
    static let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Snapshots")
    static let failures = FileManager.default.temporaryDirectory.appendingPathComponent("FolderIconerSnapshots")
    static var recording: Bool { ProcessInfo.processInfo.environment["FOLDERICONER_RECORD_SNAPSHOTS"] == "1" }

    static func verify(_ image: CGImage, named name: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        if recording {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try Bitmap.png(image).write(to: source.appendingPathComponent(name + ".png")); return
        }
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Snapshots"), "no reference \(name).png", sourceLocation: sourceLocation)
        let reference = try #require(Bitmap.decode(Data(contentsOf: url)))
        let expected = Pixels(reference), actual = Pixels(image)
        try #require(expected.width == actual.width && expected.height == actual.height, "size differs for \(name)", sourceLocation: sourceLocation)
        var diff = [UInt8](repeating: 0, count: actual.bytes.count), differing = 0, worst = 0
        for i in stride(from: 0, to: actual.bytes.count, by: 4) {
            let delta = (0..<4).map { abs(Int(actual.bytes[i + $0]) - Int(expected.bytes[i + $0])) }.max()!
            worst = max(worst, delta); if delta > 3 { differing += 1 }
            diff[i] = UInt8(min(255, delta * 4)); diff[i + 3] = 255
        }
        let ratio = Double(differing) / Double(actual.width * actual.height)
        guard ratio > 0.005 || worst > 48 else { return }
        try FileManager.default.createDirectory(at: failures, withIntermediateDirectories: true)
        try Bitmap.png(image).write(to: failures.appendingPathComponent(name + "-actual.png"))
        try Bitmap.png(Bitmap.image(rgba: diff, width: actual.width, height: actual.height)).write(to: failures.appendingPathComponent(name + "-diff.png"))
        Issue.record("\(name): \(differing) pixels differ by > 3/255 (\(String(format: "%.2f", ratio * 100)) %), worst \(worst)/255. See \(failures.path)", sourceLocation: sourceLocation)
    }
}
