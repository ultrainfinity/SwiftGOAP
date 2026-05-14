// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SwiftGOAP",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SwiftGOAP",
            targets: ["SwiftGOAP"]
        )
    ],
    dependencies: [
        // Build-time only — used by `swift package generate-documentation`
        // to produce the DocC archive deployed by .github/workflows/docs.yml.
        // No runtime impact on consumers of the SwiftGOAP product.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftGOAP",
            path: "Sources/SwiftGOAP"
        ),
        .testTarget(
            name: "SwiftGOAPTests",
            dependencies: ["SwiftGOAP"],
            path: "Tests/SwiftGOAPTests"
        )
    ]
)
