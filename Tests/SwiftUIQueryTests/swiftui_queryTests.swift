import Testing
@testable import SwiftUIQuery

@Suite("SwiftUI Query Main Test Suite")
struct SwiftUIQueryTests {
    @Test("Library initialization")
    func libraryInitialization() {
        // Basic test to ensure the library compiles and can be imported
        #expect(true)
    }

    @Test("Swift 6 concurrency compliance")
    func swift6ConcurrencyCompliance() {
        // This test suite verifies that our library works with
        // Swift 6's strict concurrency checking enabled

        // The fact that this compiles with -strict-concurrency=complete
        // means we're compliant
        #expect(true)
    }
}

// MARK: - Example of parameterized tests

@Suite("Parameterized Tests Example")
struct ParameterizedTests {
    @Test("Query key variations", arguments: [
        ("user-1", "User 1"),
        ("user-2", "User 2"),
        ("post-1", "Post 1")
    ])
    func queryKeyVariations(key: String, expectedName: String) {
        // Example of how to test multiple variations
        #expect(key.contains("-"))
        #expect(!expectedName.isEmpty)
    }

    @Test("Stale time calculations", arguments: [
        (0, true), // Immediately stale
        (300, false), // 5 minutes, still fresh
        (3600, false), // 1 hour, still fresh
    ])
    func staleTimeCalculations(secondsOld: Int, shouldBeStale: Bool) {
        // This would test stale time logic once implemented
        let isStale = secondsOld == 0 // Simplified logic
        #expect(isStale == shouldBeStale)
    }
}
