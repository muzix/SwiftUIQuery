// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftUIQuery",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "SwiftUIQuery",
            targets: ["SwiftUIQuery"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftUIQuery",
            dependencies: [
                .product(name: "Perception", package: "swift-perception")
            ]
        ),
        .testTarget(
            name: "SwiftUIQueryTests",
            dependencies: [
                "SwiftUIQuery",
            ]
        ),
    ]
)
