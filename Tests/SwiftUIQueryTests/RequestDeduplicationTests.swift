import Testing
@testable import SwiftUIQuery

/// Tests for request deduplication functionality
/// Ensures that multiple observers sharing the same query key don't trigger duplicate requests
@Suite("Request Deduplication Tests")
struct RequestDeduplicationTests {
    /// Test that multiple simultaneous fetches share the same request
    @Test("Simultaneous fetches share the same request")
    @MainActor
    func simultaneousFetchesShareRequest() async throws {
        let queryClient = QueryClient()
        queryClient.mount()
        defer {
            queryClient.clear()
            queryClient.unmount()
        }

        // Track how many times the query function is called
        let requestCounter = RequestCounter()

        let queryKey = TestQueryKey.posts
        let options = QueryOptions<String, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in
                await requestCounter.increment()
                // Simulate network delay
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                return "test-data"
            },
            staleTime: 0, // Make data immediately stale
            gcTime: 300,
            enabled: true
        )

        // Build query (this creates the query instance in cache)
        let query = queryClient.buildQuery(options: options)

        // Start multiple fetch operations simultaneously
        async let fetch1 = query.internalFetch()
        async let fetch2 = query.internalFetch()
        async let fetch3 = query.internalFetch()

        // Wait for all fetches to complete
        let results = try await (fetch1, fetch2, fetch3)

        // All fetches should return the same data
        #expect(results.0 == "test-data")
        #expect(results.1 == "test-data")
        #expect(results.2 == "test-data")

        // The query function should only have been called ONCE
        let requestCount = await requestCounter.count
        #expect(requestCount == 1, "Query function should only be called once for deduplicated requests")
    }

    /// Test that sequential fetches after completion trigger new requests
    @Test("Sequential fetches after completion trigger new requests")
    @MainActor
    func sequentialFetchesAfterCompletionTriggerNewRequests() async throws {
        let queryClient = QueryClient()
        queryClient.mount()
        defer {
            queryClient.clear()
            queryClient.unmount()
        }

        let requestCounter = RequestCounter()

        let queryKey = TestQueryKey.posts
        let options = QueryOptions<String, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in
                let count = await requestCounter.increment()
                // Return different data for each request
                return "data-\(count)"
            },
            staleTime: 0, // Make data immediately stale
            gcTime: 300,
            enabled: true
        )

        let query = queryClient.buildQuery(options: options)

        // First fetch
        let result1 = try await query.internalFetch()
        #expect(result1 == "data-1")

        // Second fetch (after first completes)
        let result2 = try await query.internalFetch()
        #expect(result2 == "data-2")

        // Third fetch (after second completes)
        let result3 = try await query.internalFetch()
        #expect(result3 == "data-3")

        // Each sequential fetch should trigger a new request
        let requestCount = await requestCounter.count
        #expect(requestCount == 3, "Sequential fetches after completion should trigger new requests")
    }

    /// Test that fetches during an ongoing fetch share the request
    @Test("Fetches during ongoing fetch share the request")
    @MainActor
    func fetchDuringOngoingFetchSharesRequest() async throws {
        let queryClient = QueryClient()
        queryClient.mount()
        defer {
            queryClient.clear()
            queryClient.unmount()
        }

        let requestCounter = RequestCounter()
        let fetchStarted = AsyncSignal()

        let queryKey = TestQueryKey.posts
        let options = QueryOptions<String, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in
                await requestCounter.increment()
                await fetchStarted.signal()
                // Long delay to ensure second fetch starts during first
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                return "shared-data"
            },
            staleTime: 0,
            gcTime: 300,
            enabled: true
        )

        let query = queryClient.buildQuery(options: options)

        // Start first fetch
        let fetch1Task = Task {
            try await query.internalFetch()
        }

        // Wait for first fetch to start
        await fetchStarted.wait()

        // Start second fetch while first is still running
        let result2 = try await query.internalFetch()

        // Wait for first fetch to complete
        let result1 = try await fetch1Task.value

        // Both should return the same data
        #expect(result1 == "shared-data")
        #expect(result2 == "shared-data")

        // Query function should only be called once
        let requestCount = await requestCounter.count
        #expect(requestCount == 1, "Fetch during ongoing fetch should share the request")
    }

    /// Test that cancelling doesn't affect other observers sharing the request
    @Test("Cancelling doesn't affect shared request")
    @MainActor
    func cancelDoesNotAffectSharedRequest() async throws {
        let queryClient = QueryClient()
        queryClient.mount()
        defer {
            queryClient.clear()
            queryClient.unmount()
        }

        let requestCounter = RequestCounter()
        let fetchStarted = AsyncSignal()

        let queryKey = TestQueryKey.posts
        let options = QueryOptions<String, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in
                await requestCounter.increment()
                await fetchStarted.signal()
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                return "cancel-test-data"
            },
            staleTime: 0,
            gcTime: 300,
            enabled: true
        )

        let query = queryClient.buildQuery(options: options)

        // Start two fetches
        let fetch1Task = Task {
            try await query.internalFetch()
        }

        // Wait for fetch to start
        await fetchStarted.wait()

        // Start second fetch (should share the request)
        let fetch2Task = Task {
            try await query.internalFetch()
        }

        // Give second fetch time to start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Cancel the first task
        fetch1Task.cancel()

        // Second fetch should still complete successfully
        let result2 = try await fetch2Task.value
        #expect(result2 == "cancel-test-data")

        // Query function should only be called once
        let requestCount = await requestCounter.count
        #expect(requestCount == 1, "Cancelled task should not affect shared request")
    }

    /// Test error handling with deduplicated requests
    @Test("Error handling with deduplication")
    @MainActor
    func errorHandlingWithDeduplication() async throws {
        let queryClient = QueryClient()
        queryClient.mount()
        defer {
            queryClient.clear()
            queryClient.unmount()
        }

        let requestCounter = RequestCounter()

        let queryKey = TestQueryKey.posts
        let options = QueryOptions<String, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in
                await requestCounter.increment()
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                throw QueryError.queryFailed(RequestDeduplicationTestError.simulatedError)
            },
            retryConfig: RetryConfig(retryAttempts: .never), // No retries
            staleTime: 0,
            gcTime: 300,
            enabled: true
        )

        let query = queryClient.buildQuery(options: options)

        // Start multiple fetches
        async let fetch1 = query.internalFetch()
        async let fetch2 = query.internalFetch()
        async let fetch3 = query.internalFetch()

        // All should fail with the same error
        var error1: Error?
        var error2: Error?
        var error3: Error?

        do {
            _ = try await fetch1
        } catch {
            error1 = error
        }

        do {
            _ = try await fetch2
        } catch {
            error2 = error
        }

        do {
            _ = try await fetch3
        } catch {
            error3 = error
        }

        #expect(error1 is QueryError, "First fetch should throw QueryError")
        #expect(error2 is QueryError, "Second fetch should throw QueryError")
        #expect(error3 is QueryError, "Third fetch should throw QueryError")

        // Query function should only be called once
        let requestCount = await requestCounter.count
        #expect(requestCount == 1, "Failed deduplicated requests should share the same error")
    }

    /// Test that removing all observers cancels ongoing fetch
    @Test("Removing all observers cancels ongoing fetch")
    @MainActor
    func removingAllObserversCancelsOngoingFetch() async throws {
        let queryClient = QueryClient()
        queryClient.mount()
        defer {
            queryClient.clear()
            queryClient.unmount()
        }

        let requestCounter = RequestCounter()
        let fetchStarted = AsyncSignal()

        let queryKey = TestQueryKey.posts
        let options = QueryOptions<String, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in
                await requestCounter.increment()
                await fetchStarted.signal()
                // Long delay to simulate slow network
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                return "should-be-cancelled"
            },
            staleTime: 0,
            gcTime: 300,
            enabled: true
        )

        let query = queryClient.buildQuery(options: options)

        // Add a mock observer
        let observer = MockQueryObserver()
        query.addObserver(observer)

        // Start fetch
        let fetchTask = Task {
            try await query.internalFetch()
        }

        // Wait for fetch to start
        await fetchStarted.wait()

        // Verify fetch is running
        #expect(query.state.fetchStatus == .fetching)

        // Remove the observer (should cancel the fetch)
        query.removeObserver(observer)

        // Verify fetch was cancelled
        do {
            _ = try await fetchTask.value
            Issue.record("Expected fetch to be cancelled")
        } catch {
            // This is expected - fetch should be cancelled
        }

        // Verify query is no longer fetching
        #expect(query.state.fetchStatus != .fetching)

        // Query function should have been called once (before cancellation)
        let requestCount = await requestCounter.count
        #expect(requestCount == 1, "Query function should be called once before cancellation")
    }
}

// MARK: - Mock Observer for Testing

/// Mock observer for testing observer lifecycle
private class MockQueryObserver: AnyQueryObserver {
    let id = QueryObserverIdentifier()

    func getCurrentResult() -> any AnyQueryResult {
        MockQueryResult()
    }

    func onQueryUpdate() {
        // No-op for testing
    }

    func isEnabled() -> Bool {
        true
    }

    func shouldFetchOnWindowFocus() -> Bool {
        false
    }

    func shouldFetchOnReconnect() -> Bool {
        false
    }

    func refetch(cancelRefetch: Bool) {
        // No-op for testing
    }
}

/// Mock query result for testing
private struct MockQueryResult: AnyQueryResult {
    let isStale = false
}

// MARK: - Test Helpers

/// Helper to count async function calls
private actor RequestCounter {
    private var _count = 0

    var count: Int {
        _count
    }

    @discardableResult
    func increment() -> Int {
        _count += 1
        return _count
    }

    func reset() {
        _count = 0
    }
}

/// Helper for async signaling between tasks
private actor AsyncSignal {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func signal() {
        continuation?.resume()
        continuation = nil
    }
}

/// Test error for request deduplication tests
private enum RequestDeduplicationTestError: Error {
    case simulatedError
}
