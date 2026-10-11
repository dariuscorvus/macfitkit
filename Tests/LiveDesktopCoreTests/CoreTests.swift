import Foundation
import XCTest
@testable import LiveDesktopCore

final class CoreTests: XCTestCase {
func testCatalogUsesOnlyLocalRegularVideosAndDeduplicates() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let video = root.appendingPathComponent("nested/landscape.MOV")
    try Data([0]).write(to: video)
    try Data([0]).write(to: root.appendingPathComponent("metadata.json"))
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("alias.mov"), withDestinationURL: video)
    let result = AssetCatalog.scan(roots: [root, root, root.appendingPathComponent("missing")])
    XCTAssertEqual(result.assets.map(\.url), [video])
    XCTAssertEqual(result.warnings.count, 0)
}

func testPauseReasonsCannotOverrideManualPause() {
    for manual in [false, true] {
        for sleep in [false, true] {
            for power in [false, true] {
                for thermal in [false, true] {
                    let result = PlaybackPolicy.shouldPlay(manualPause: manual, sleeping: sleep, lowPower: power, thermalBlocked: thermal)
                    XCTAssertEqual(result, !(manual || sleep || power || thermal))
                }
            }
        }
    }
}

func testAppleMetadataUsesLocalizedNamesAndOnlyDownloadedVideos() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let resources = root.appendingPathComponent("TVIdleScreenStrings.bundle/Contents/Resources")
    let videos = root.appendingPathComponent("videos")
    let thumbnails = root.appendingPathComponent("thumbnails")
    for directory in [resources, videos, thumbnails] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let id = "F88CDF4A-9681-4D1F-88FE-34F1A3C6A62B"
    let url = videos.appendingPathComponent(id.lowercased() + ".mov")
    try Data([0]).write(to: url)
    let thumbnail = thumbnails.appendingPathComponent(id + ".png")
    try Data([0]).write(to: thumbnail)
    let entries: [String: Any] = [
        "assets": [
            ["id": id, "accessibilityLabel": "Sequoia Morning", "localizedNameKey": "MORNING", "categories": ["landscape"], "url-4K-SDR": "https://example.invalid/video.mov"],
            ["id": "6D6834A4-2F0F-479A-B053-7D4DC5CB8EB7", "accessibilityLabel": "Not downloaded", "categories": ["landscape"]]
        ],
        "categories": [["id": "landscape", "localizedNameKey": "LANDSCAPE"]]
    ]
    let manifest = root.appendingPathComponent("entries.json")
    try JSONSerialization.data(withJSONObject: entries).write(to: manifest)
    let strings = ["en": ["MORNING": "Sequoia Morning", "LANDSCAPE": "Landscape"], "de": ["MORNING": "Mammutbaum am Morgen", "LANDSCAPE": "Landschaft"]]
    try PropertyListSerialization.data(fromPropertyList: strings, format: .binary, options: 0).write(to: resources.appendingPathComponent("Localizable.nocache.loctable"))
    let result = AssetCatalog.scan(roots: [videos], manifestURLs: [manifest], thumbnailRoots: [thumbnails], preferredLanguages: ["de-DE"])
    XCTAssertEqual(result.assets.count, 1)
    XCTAssertEqual(result.assets.first?.name, "Mammutbaum am Morgen")
    XCTAssertEqual(result.assets.first?.category, "Landschaft")
    XCTAssertEqual(result.assets.first?.thumbnailURL, thumbnail)
    XCTAssertEqual(result.assets.first?.appleID, id)
    let english = AssetCatalog.scan(roots: [videos], manifestURLs: [manifest], thumbnailRoots: [], preferredLanguages: ["fr"])
    XCTAssertEqual(english.assets.first?.name, "Sequoia Morning")
}

func testMalformedMetadataKeepsLocalVideosSelectable() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("custom.mov")
    try Data([0]).write(to: file)
    let manifest = root.appendingPathComponent("entries.json")
    try Data("broken".utf8).write(to: manifest)
    let result = AssetCatalog.scan(roots: [], manifestURLs: [manifest], thumbnailRoots: [], explicitFiles: [file])
    XCTAssertEqual(result.assets.first?.name, "custom")
    XCTAssertEqual(result.warnings.count, 1)
}

func testRotationSequence() {
    XCTAssertEqual(RotationSequence.next(current: "a", paths: []), nil)
    XCTAssertEqual(RotationSequence.next(current: "a", paths: ["a", "a"]), nil)
    XCTAssertEqual(RotationSequence.next(current: "a", paths: ["a", "b", "c"]), "b")
    XCTAssertEqual(RotationSequence.next(current: "c", paths: ["a", "b", "c"]), "a")
    XCTAssertEqual(RotationSequence.next(current: "removed", paths: ["b", "c"]), "b")
    XCTAssertEqual(RotationSequence.next(current: "a", paths: ["a", "a", "b"]), "b")
}

func testPersistentSettingsAndShuffle() throws {
    var settings = LiveSettings(); settings.manualPause = true; settings.pauseOnLowPower = false
    settings.rotationPaths = ["b", "a", "b"]; settings.rotationMinutes = -10
    var options = LibraryOptions(); options.pauseOnBattery = true; options.shuffle = true
    options.playlists = [VideoPlaylist(id: "test", name: "Test", paths: ["b", "a"])]
    settings.library = options
    let restored = try JSONDecoder().decode(LiveSettings.self, from: JSONEncoder().encode(settings.normalized))
    XCTAssertEqual(restored.manualPause, true); XCTAssertEqual(restored.pauseOnLowPower, false)
    XCTAssertEqual(restored.rotationPaths, ["b", "a"]); XCTAssertEqual(restored.rotationMinutes, 15)
    XCTAssertEqual(restored.library, options)
    var cycle = ShuffleCycle(); var current = "a"
    for _ in 0..<50 {
        var round: [String] = []
        for _ in 0..<3 {
            let next = cycle.next(current: current, paths: ["a","b","c","a"])!
            XCTAssertEqual(next == current, false); current = next; round.append(next)
        }
        XCTAssertEqual(Set(round), Set(["a","b","c"]))
    }
    XCTAssertEqual(cycle.next(current: "a", paths: ["a"]), nil)
}

}
