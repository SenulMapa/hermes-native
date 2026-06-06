// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HermesAPI",
    // macOS included so the pure-Foundation networking tests run on the CI host
    // via `swift test` (no simulator needed). The app still targets iOS 26+.
    platforms: [.iOS(.v26), .macOS(.v13)],
    products: [
        .library(name: "HermesAPI", targets: ["HermesAPI"]),
    ],
    targets: [
        .target(name: "HermesAPI"),
        .testTarget(name: "HermesAPITests", dependencies: ["HermesAPI"]),
    ],
    swiftLanguageModes: [.v5]
)
