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
