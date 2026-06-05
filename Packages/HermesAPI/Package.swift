// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HermesAPI",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "HermesAPI", targets: ["HermesAPI"]),
    ],
    targets: [
        .target(name: "HermesAPI"),
        .testTarget(name: "HermesAPITests", dependencies: ["HermesAPI"]),
    ],
    swiftLanguageModes: [.v5]
)
