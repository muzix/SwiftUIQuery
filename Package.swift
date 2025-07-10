// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftUIQuery",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
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
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "SwiftUIQuery",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftUIQueryTests",
            dependencies: [
                "SwiftUIQuery",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)
