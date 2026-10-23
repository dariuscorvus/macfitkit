// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "FolderIconer", platforms: [.macOS(.v14)], products: [
    .library(name: "FolderIconerCore", targets: ["FolderIconerCore"]),
    .executable(name: "foldericoner-render", targets: ["FolderIconerRender"])
], targets: [
    .target(name: "FolderIconerCore"),
    .executableTarget(name: "FolderIconerRender", dependencies: ["FolderIconerCore"]),
    .testTarget(name: "FolderIconerCoreTests", dependencies: ["FolderIconerCore"], resources: [.copy("Snapshots")])
])
