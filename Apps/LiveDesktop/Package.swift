// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "LiveDesktop",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "LiveDesktop", targets: ["LiveDesktop"])],
    targets: [
        .target(name: "LiveDesktopCore"),
        .executableTarget(name: "LiveDesktop", dependencies: ["LiveDesktopCore"]),
        .testTarget(name: "LiveDesktopCoreTests", dependencies: ["LiveDesktopCore"])
    ],
    swiftLanguageModes: [.v6]
)
