// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "UniversalPiP", platforms: [.macOS(.v14)], products: [
    .library(name: "UniversalPiP", targets: ["UniversalPiP"])
], targets: [.target(name: "UniversalPiP"), .testTarget(name: "UniversalPiPTests", dependencies: ["UniversalPiP"])])
