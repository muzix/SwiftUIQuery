# SwiftUI Query - Core Principles

## Project Philosophy
SwiftUI Query is a Swift implementation of TanStack Query's powerful asynchronous state management, specifically designed for SwiftUI applications.

## Core Principles

### 1. API Familiarity
- Mirror TanStack Query's API design patterns where possible
- Adapt naming conventions to Swift standards
- Maintain conceptual compatibility for easy migration

### 2. SwiftUI Native
- Built exclusively for SwiftUI, not UIKit
- Leverage SwiftUI's state management (@State, @StateObject, @ObservedObject)
- Respect SwiftUI's declarative paradigm
- Work seamlessly with SwiftUI's lifecycle

### 3. Type Safety First
- Leverage Swift's strong type system for compile-time safety
- No stringly-typed APIs
- Generic constraints for better developer experience
- Comprehensive error handling with Swift's Result type

### 4. Modern Concurrency
- Built on Swift's async/await
- Use actors for thread-safe state management
- Support structured concurrency with TaskGroup
- Proper cancellation support

### 5. Swift 6 Strict Concurrency
- Full compatibility with Swift 6's strict concurrency mode
- All types properly marked with `Sendable` conformance
- No data races or concurrency warnings
- Proper isolation with `@MainActor` for UI updates
- Use `nonisolated` and `isolated` parameters appropriately

### 6. Network Agnostic
- No dependency on specific networking libraries
- Users bring their own networking implementation
- Support any async throwing function as data source
- Focus on state management, not network requests

### 7. Zero Dependencies
- No external package dependencies
- Use only Swift standard library and SwiftUI
- Optional Combine integration for reactive patterns
- Lightweight and easy to integrate

### 8. Developer Experience
- Intuitive API that feels natural in Swift
- Comprehensive documentation with examples
- Clear error messages
- SwiftUI preview support

## Design Philosophy

### Declarative Over Imperative
Embrace SwiftUI's declarative nature. Queries should be declared, not imperatively fetched.

### Composition Over Inheritance
Use protocols and generics for extensibility rather than class hierarchies.

### Convention Over Configuration
Provide sensible defaults while allowing customization when needed.

### Progressive Disclosure
Simple things should be simple, complex things should be possible.

## Swift 6 Compliance Guidelines

### Sendable Conformance
- All public types must be `Sendable`
- Use `struct` over `class` where possible
- For classes, ensure thread safety with actors or locks
- Mark non-Sendable types explicitly with `@unchecked Sendable` only when absolutely safe

### Actor Isolation
- Query cache managed by dedicated actor
- UI updates isolated to `@MainActor`
- Background operations properly isolated
- Clear boundaries between isolation domains

### Example Patterns
```swift
// Sendable query result
struct QueryResult<T: Sendable>: Sendable {
    let data: T
    let timestamp: Date
}

// Actor for cache management
actor QueryCache {
    private var storage: [AnyHashable: any Sendable] = [:]
    
    func get<T: Sendable>(_ key: QueryKey) -> T? {
        storage[key] as? T
    }
}

// MainActor for UI updates
@MainActor
class QueryState<T: Sendable>: ObservableObject {
    @Published var value: QueryResult<T>?
}
```