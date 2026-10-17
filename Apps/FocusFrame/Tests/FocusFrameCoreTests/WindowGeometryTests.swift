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

struct WindowOcclusionTests {
    let area = CGRect(x: -100, y: 50, width: 200, height: 100)

    @Test func overlappingOccludersAreAUnion() {
        let covers = [CGRect(x: -100, y: 50, width: 120, height: 100),
                      CGRect(x: -20, y: 50, width: 100, height: 100)]
        let regions = WindowOcclusion.visibleRegions(in: area, coveredBy: covers)
        #expect(regions.reduce(0) { $0 + $1.width * $1.height } == 2000)
        for x in stride(from: -99.5, to: 100, by: 1) {
            let point = CGPoint(x: x, y: 90)
            #expect(regions.contains { $0.contains(point) } == !covers.contains { $0.contains(point) })
        }
    }

    @Test func fullCoverAndReveal() {
        #expect(WindowOcclusion.visibleRegions(in: area, coveredBy: [area]) == [])
        #expect(WindowOcclusion.visibleRegions(in: area, coveredBy: []) == [area])
        #expect(WindowOcclusion.visibleRegions(in: area, coveredBy: [area.offsetBy(dx: 500, dy: 0)]) == [area])
    }

    @Test func subtractionKeepsDisjointFractionalRegions() {
        let cover = CGRect(x: -75.25, y: 60.5, width: 85.5, height: 70.25)
        let regions = WindowOcclusion.visibleRegions(in: area, coveredBy: [cover, cover])
        #expect(abs(regions.reduce(0) { $0 + $1.width * $1.height } - (20000 - cover.width * cover.height)) < 0.0001)
        for i in regions.indices {
            #expect(!regions[i].intersects(cover))
            for j in regions.indices where i < j { #expect(!regions[i].intersects(regions[j])) }
        }
    }

    @Test func identityRequiresUniqueProcessAndGeometry() {
        let stack = [WindowStackEntry(id: 1, pid: 12, bounds: area),
                     WindowStackEntry(id: 2, pid: 34, bounds: area)]
        #expect(WindowOcclusion.target(in: stack, pid: 34, bounds: area) == 1)
        #expect(WindowOcclusion.target(in: stack, pid: 99, bounds: area) == nil)
        #expect(WindowOcclusion.target(in: stack, pid: 34, bounds: area.offsetBy(dx: 50, dy: 30), knownID: 2) == 1)
        #expect(WindowOcclusion.target(in: stack, pid: 99, bounds: area, knownID: 2) == nil)
        let duplicates = stack + [WindowStackEntry(id: 3, pid: 34, bounds: area)]
        #expect(WindowOcclusion.target(in: duplicates, pid: 34, bounds: area) == nil)
        #expect(WindowOcclusion.target(in: duplicates, pid: 34, bounds: area, knownID: 2) == 1)
        #expect(WindowOcclusion.target(in: stack, pid: 34, bounds: area.offsetBy(dx: 3, dy: 0)) == nil)
    }
}
