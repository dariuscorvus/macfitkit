// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusFrame",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusFrame", targets: ["FocusFrame"]),
        .executable(name: "FocusFrameFixture", targets: ["FocusFrameFixture"])
    ],
    dependencies: [.package(path: "../../Packages/MacFitKitShared")],
    targets: [
        .target(name: "FocusFrameCore"),
        .executableTarget(name: "FocusFrame", dependencies: ["FocusFrameCore", .product(name: "MacFitKitCore", package: "MacFitKitShared"), .product(name: "MacFitKitUI", package: "MacFitKitShared"), .product(name: "MacFitKitPlatform", package: "MacFitKitShared")]),
        .executableTarget(name: "FocusFrameFixture"),
        .testTarget(name: "FocusFrameCoreTests", dependencies: ["FocusFrameCore"])
    ]
)
