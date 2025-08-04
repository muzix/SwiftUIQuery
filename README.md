# SwiftUI Query

A Swift implementation of TanStack Query for SwiftUI applications, providing powerful asynchronous state management with caching, synchronization, and infinite queries.

## Features

- 🚀 **Swift 6 Compatible** - Full strict concurrency support
- 🔄 **Automatic Refetching** - On mount, focus, reconnect
- 📱 **iOS 16+ Support** - Built with Perception library for broad compatibility
- ⚡️ **Request Deduplication** - Automatic request optimization
- 🗑️ **Garbage Collection** - Smart memory management
- 📊 **Infinite Queries** - Built-in pagination support
- 🔧 **Type Safe** - Full Swift type safety
- 📱 **Multi-Platform** - iOS, macOS, tvOS, and watchOS

## Requirements

- Swift 6.0+
- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+

## Installation

### Swift Package Manager

Add SwiftUI Query to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/muzix/SwiftUIQuery.git", from: "0.2.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/muzix/SwiftUIQuery.git`
3. Select the version

## Quick Start

### 1. Set up QueryClient

```swift
import SwiftUI
import SwiftUIQuery

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .queryClient() // Add QueryClient to environment
        }
    }
}
```

### 2. Basic Query

```swift
import SwiftUI
import SwiftUIQuery

struct ContentView: View {
    var body: some View {
        UseQuery(
            queryKey: "todos",
            queryFn: { _ in
                try await fetchTodos()
            }
        ) { result in
            switch result.status {
            case .loading:
                ProgressView("Loading...")
            case .error:
                Text("Error: \(result.error?.localizedDescription ?? "Unknown error")")
            case .success:
                List(result.data ?? []) { todo in
                    Text(todo.title)
                }
            }
        }
    }
    
    func fetchTodos() async throws -> [Todo] {
        // Your API call here
    }
}
```

### 3. Infinite Query

```swift
struct PokemonListView: View {
    var body: some View {
        UseInfiniteQuery(
            queryKey: "pokemon-list",
            queryFn: { _, pageParam in
                let offset = pageParam ?? 0
                return try await PokemonAPI.fetchPokemonPage(offset: offset)
            },
            getNextPageParam: { pages in
                let currentTotal = pages.reduce(0) { total, page in 
                    total + page.results.count 
                }
                return pages.last?.next != nil ? currentTotal : nil
            },
            initialPageParam: 0
        ) { result in
            ScrollView {
                LazyVStack {
                    // Render all pages
                    ForEach(result.data?.pages ?? []) { page in
                        ForEach(page.results) { pokemon in
                            PokemonRow(pokemon: pokemon)
                        }
                    }
                    
                    // Load more button
                    if result.hasNextPage {
                        Button("Load More") {
                            Task {
                                await result.fetchNextPage()
                            }
                        }
                        .onAppear {
                            // Auto-load on scroll
                            Task {
                                await result.fetchNextPage()
                            }
                        }
                    }
                }
            }
            .refreshable {
                try? await result.refetch()
            }
        }
    }
}
```

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