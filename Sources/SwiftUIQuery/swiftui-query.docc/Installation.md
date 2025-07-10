# Installation

Learn how to add SwiftUI Query to your project.

## Overview

SwiftUI Query is distributed as a Swift Package Manager package. It supports iOS 16+, macOS 13+, tvOS 16+, and watchOS 9+.

## Swift Package Manager

### Xcode Integration

1. Open your project in Xcode
2. Go to **File** → **Add Package Dependencies**
3. Enter the repository URL: `https://github.com/muzix/swiftui-query`
4. Select the version you want to use
5. Click **Add Package**

### Package.swift Integration

Add SwiftUI Query to your `Package.swift` file:

```swift
dependencies: 
    .package(url: "https://github.com/muzix/swiftui-query", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SwiftUIQuery", package: "swiftui-query")
        ]
    )
]
```

## Requirements

- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 5.9+
- Xcode 15.0+

## Next Steps

- <doc:QuickStart>
- <doc:BasicUsage>
