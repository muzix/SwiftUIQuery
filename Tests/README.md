# SwiftUI Query Test Infrastructure

## Overview
This test suite is built using Swift Testing framework and provides comprehensive testing for SwiftUI Query development.

## Test Structure

### Test Organization
```
Tests/swiftui-queryTests/
├── Core/                     # Core functionality tests
│   └── QueryStateTests.swift
├── PropertyWrapper/          # Property wrapper tests (future)
├── Cache/                    # Cache implementation tests (future)
├── Concurrency/              # Swift 6 concurrency tests
│   └── SendableComplianceTests.swift
├── Integration/              # SwiftUI integration tests
│   └── SwiftUIIntegrationTests.swift
├── Helpers/                  # Test utilities and helpers
│   └── TestHelpers.swift
└── swiftui_queryTests.swift  # Main test suite
```

### Key Features

#### 1. Swift Testing Framework
- Modern testing with `@Test` and `@Suite` attributes
- Parameterized tests with multiple arguments
- Custom test traits (like `@Test.timeout`)
- Clear test organization and grouping

#### 2. Swift 6 Concurrency Testing
- Sendable conformance verification
- Actor isolation testing
- Data race detection
- Concurrent operation testing

#### 3. Test Helpers
- `MockNetworkClient` for async testing
- `TestEnvironment` for setup/teardown
- `waitFor()` utility for async assertions
- `performConcurrentOperations()` for concurrency testing

#### 4. SwiftUI Integration
- ViewInspector integration for UI testing
- Lifecycle testing (onAppear, scene changes)
- Property wrapper testing

## Running Tests

### Basic Test Run
```bash
swift test
```

### With Strict Concurrency
```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency --parallel
```

### Using Test Script
```bash
./Scripts/test.sh
```

## Test Categories

### 1. Core Type Tests
Tests for fundamental types like `QueryState`, `QueryOptions`, etc.

### 2. Concurrency Tests
- Sendable compliance verification
- Actor isolation testing
- Thread safety validation

### 3. Integration Tests
- SwiftUI view testing
- Property wrapper lifecycle
- Real-world usage scenarios

### 4. Performance Tests
- Concurrent access patterns
- Cache performance
- Memory management

## Test Helpers

### MockNetworkClient
```swift
let mockClient = MockNetworkClient()
mockClient.setResponse(for: "user-1", response: testUser)
mockClient.setError(for: "posts", error: TestError.networkError)
let result = try await mockClient.fetch("user-1")
```

### Async Assertions
```swift
try await waitFor {
    query.status == .success
}
```

### Concurrency Testing
```swift
let results = try await performConcurrentOperations(count: 100) {
    cache.getValue("test-key")
}
```

## Test Data Models
- `TestUser`: Simple user model for testing
- `TestPost`: Post model for testing
- `TestQueryKey`: Enum-based query keys
- `TestError`: Custom error types

## Current Status
✅ Test infrastructure set up
✅ Swift Testing framework configured
✅ Swift 6 strict concurrency enabled
✅ ViewInspector integration ready
✅ Mock helpers available
✅ 19 placeholder tests passing

## Next Steps
As we implement the actual SwiftUI Query features:
1. Update placeholder tests with real implementations
2. Add comprehensive test coverage for each feature
3. Implement integration tests for real scenarios
4. Add performance benchmarks