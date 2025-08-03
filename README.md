# SwiftUI Query

A Swift implementation of TanStack Query for SwiftUI applications, providing powerful asynchronous state management with caching, synchronization, and more.

## Features

- 🚀 Swift 6 compatible with strict concurrency
- 📦 Zero external dependencies
- 🔄 Automatic refetching (on mount, focus, reconnect)
- ⚡️ Request deduplication
- 🗑️ Garbage collection
- 📊 Parallel and dependent queries
- 🔧 Built with Swift Observation framework
- 📱 Support for iOS, macOS, tvOS, and watchOS

## Requirements

- Swift 6.0+
- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+

## Installation

### Swift Package Manager

Add SwiftUI Query to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/muzix/swiftui-query.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version

## Development

### Setup

1. Clone the repository
2. Install development tools:
   ```bash
   brew bundle
   ```

### Code Quality

This project uses SwiftLint and SwiftFormat to maintain code quality and consistency.

#### Available Commands

```bash
make help        # Show all available commands
make lint        # Run SwiftLint
make lint-fix    # Auto-fix SwiftLint issues
make format      # Format code with SwiftFormat
make format-check # Check if formatting is needed
make check       # Run all checks (lint + format)
make fix         # Fix all issues (lint + format)
make build       # Build with strict concurrency
make test        # Run tests
make ci          # Run full CI suite
```

#### Pre-commit Hook (Optional)

To ensure code quality before commits:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
make check
EOF
chmod +x .git/hooks/pre-commit
```

### Project Structure

### Testing

Run tests with strict concurrency:
```bash
make test
```

### Documentation

The project follows TanStack Query's architecture. Key documentation:
- `CLAUDE.md` - Development guide and instructions
- `principles.md` - Core principles and Swift 6 compliance
- `api-design.md` - API patterns and usage examples
- `roadmap.md` - Development roadmap
- `feature-parity.md` - TanStack Query feature comparison

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run `make check` to ensure code quality
4. Commit your changes
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

[MIT License](LICENSE)

## Acknowledgments

This project is inspired by [TanStack Query](https://tanstack.com/query) and aims to bring its powerful features to the Swift ecosystem.