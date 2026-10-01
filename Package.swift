// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusFrame",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FocusFrame", targets: ["FocusFrame"])],
    targets: [
        .target(name: "FocusFrameCore"),
        .executableTarget(name: "FocusFrame", dependencies: ["FocusFrameCore"]),
        .testTarget(name: "FocusFrameCoreTests", dependencies: ["FocusFrameCore"])
    ]
)
