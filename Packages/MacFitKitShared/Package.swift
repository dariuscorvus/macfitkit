// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MacFitKitShared", platforms: [.macOS(.v14)], products: [
    .library(name: "MacFitKitCore", targets: ["MacFitKitCore"]),
    .library(name: "MacFitKitPlatform", targets: ["MacFitKitPlatform"]),
    .library(name: "MacFitKitUI", targets: ["MacFitKitUI"])
], targets: [
    .target(name: "MacFitKitCore"),
    .target(name: "MacFitKitPlatform", dependencies: ["MacFitKitCore"]),
    .target(name: "MacFitKitUI", dependencies: ["MacFitKitCore", "MacFitKitPlatform"]),
    .testTarget(name: "MacFitKitSharedTests", dependencies: ["MacFitKitCore", "MacFitKitPlatform", "MacFitKitUI"])
])
