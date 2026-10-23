import Testing
@testable import FolderIconerCore

private let snapshotFixtures = ["base-system", "base-color-green", "image-fill-clipped-rotated", "text-gradient", "emoji-rotated-half-opacity", "issue-14-example"] + IconFixtures.kindNames

@Test(arguments: snapshotFixtures, [32, 256])
func snapshotMatchesReference(fixture: String, points: Int) throws {
    let package = try #require(IconFixtures.package(named: fixture))
    try Snapshot.verify(fixtureRenderer.render(package, points: points, scale: 1), named: "\(fixture)-\(points)")
}
