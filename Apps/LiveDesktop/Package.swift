// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "LiveDesktop",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "LiveDesktop", targets: ["LiveDesktop"])],
    dependencies: [.package(path: "../../Packages/MacFitKitShared")],
    targets: [
        .target(name: "LiveDesktopCore"),
        .executableTarget(name: "LiveDesktop", dependencies: ["LiveDesktopCore", .product(name: "MacFitKitUI", package: "MacFitKitShared"), .product(name: "MacFitKitPlatform", package: "MacFitKitShared")]),
        .testTarget(name: "LiveDesktopCoreTests", dependencies: ["LiveDesktopCore"])
    ],
    swiftLanguageModes: [.v6]
)
