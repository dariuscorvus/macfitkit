// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "UniversalPiP", platforms: [.macOS(.v14)], products: [
    .library(name: "UniversalPiP", targets: ["UniversalPiP"])
], targets: [.target(name: "UniversalPiP", sources: ["CaptureSession.swift", "PiPModels.swift", "PiPPanelController.swift", "PiPSessionCoordinator.swift", "WindowSourceProvider.swift"]), .testTarget(name: "UniversalPiPTests", dependencies: ["UniversalPiP"], sources: ["PiPTests.swift"])])
