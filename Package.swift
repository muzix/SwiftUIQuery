// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swiftui-query",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "swiftui-query",
            targets: ["swiftui-query"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "swiftui-query",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "swiftui-queryTests",
            dependencies: [
                "swiftui-query",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)
