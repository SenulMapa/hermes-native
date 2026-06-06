// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HermesTerminal",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "HermesTerminal", targets: ["HermesTerminal"]),
    ],
    dependencies: [
        // SwiftTerm: the established iOS terminal emulator.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
        // SSH transport: Apple's official libraries only (no third-party forks).
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "HermesTerminal",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
