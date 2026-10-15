// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusFrame",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusFrame", targets: ["FocusFrame"]),
        .executable(name: "FocusFrameFixture", targets: ["FocusFrameFixture"])
    ],
    targets: [
        .target(name: "FocusFrameCore"),
        .executableTarget(name: "FocusFrame", dependencies: ["FocusFrameCore"]),
        .executableTarget(name: "FocusFrameFixture"),
        .testTarget(name: "FocusFrameCoreTests", dependencies: ["FocusFrameCore"])
    ]
)
