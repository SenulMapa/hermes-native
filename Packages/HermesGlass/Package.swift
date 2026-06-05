// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HermesGlass",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "HermesGlass", targets: ["HermesGlass"]),
    ],
    targets: [
        .target(name: "HermesGlass"),
        .testTarget(name: "HermesGlassTests", dependencies: ["HermesGlass"]),
    ],
    swiftLanguageModes: [.v5]
)
