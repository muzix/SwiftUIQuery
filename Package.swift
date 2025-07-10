// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftUIQuery",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
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
