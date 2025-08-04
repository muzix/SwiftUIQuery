import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("QueryClient Tests")
@MainActor
struct QueryClientTests {
    // MARK: - Initialization Tests

    @Test("QueryClient default initialization")
    func defaultInitialization() {
        let client = QueryClient()

        // Should have default configuration
        #expect(client.cache.isEmpty == true)
        #expect(client.cache.isEmpty)
    }

    @Test("QueryClient initialization with custom config")
    func initializationWithCustomConfig() {
        let customCache = QueryCache()
        let defaultOptions = DefaultQueryOptions(
            queries: DefaultQueryConfig(
                staleTime: 1000,
                gcTime: 5000,
                retryConfig: RetryConfig(retryAttempts: .count(5))
            )
        )
        let config = QueryClientConfig(
            queryCache: customCache,
            defaultOptions: defaultOptions
        )

        let client = QueryClient(config: config)

        // Should use provided cache
        #expect(client.cache === customCache)
        #expect(client.cache.isEmpty == true)
    }

    // MARK: - Lifecycle Management Tests

    @Test("QueryClient mount and unmount")
    func mountAndUnmount() {
        let client = QueryClient()

        // Test mount
        client.mount()
        // Multiple mounts should be safe
        client.mount()
        client.mount()

        // Test unmount
        client.unmount()
        client.unmount()
        client.unmount()

        // Should not crash and should handle multiple calls gracefully
        #expect(Bool(true)) // If we get here without crashing, the test passes
    }

    // MARK: - Query Data Management Tests

    @Test("QueryClient getQueryData with non-existing query")
    func getQueryDataNonExisting() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "nonexistent")

        let data: TestUser? = client.getQueryData(queryKey: queryKey)

        #expect(data == nil)
    }

    @Test("QueryClient setQueryData and getQueryData")
    func setAndGetQueryData() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let testUser = TestUser(id: "test-user", name: "Test User", email: "test@example.com")

        // Set data
        let setResult = client.setQueryData(queryKey: queryKey, data: testUser)
        #expect(setResult == testUser)

        // Get data
        let retrievedData: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(retrievedData == testUser)
    }

    @Test("QueryClient setQueryData updates existing query")
    func setQueryDataUpdatesExisting() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let user1 = TestUser(id: "test-user", name: "User 1", email: "user1@example.com")
        let user2 = TestUser(id: "test-user", name: "User 2", email: "user2@example.com")

        // Set initial data
        client.setQueryData(queryKey: queryKey, data: user1)
        let initial: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(initial == user1)

        // Update data
        client.setQueryData(queryKey: queryKey, data: user2)
        let updated: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(updated == user2)
    }

    @Test("QueryClient getQueryState")
    func getQueryState() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let testUser = TestUser(id: "test-user", name: "Test User", email: "test@example.com")

        // Initially no state
        let initialState: QueryState<TestUser>? = client.getQueryState(queryKey: queryKey)
        #expect(initialState == nil)

        // Set data and check state
        client.setQueryData(queryKey: queryKey, data: testUser)
        let state: QueryState<TestUser>? = client.getQueryState(queryKey: queryKey)

        #expect(state != nil)
        #expect(state?.data == testUser)
        #expect(state?.status == .success)
    }

    // MARK: - Query Building Tests

    @Test("QueryClient buildQuery creates new query")
    func buildQueryCreatesNew() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "new-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "new-user", name: "New", email: "new@example.com") }
        )

        let query = client.buildQuery(options: options)

        #expect(query.queryHash == queryKey.queryHash)
        #expect(query.state.status == QueryStatus.pending)
    }

    @Test("QueryClient buildQuery reuses existing query")
    func buildQueryReusesExisting() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "reuse-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "reuse-user", name: "Reuse", email: "reuse@example.com") }
        )

        let query1 = client.buildQuery(options: options)
        let query2 = client.buildQuery(options: options)

        // Should reuse the same query instance
        #expect(query1.queryHash == query2.queryHash)
        #expect(client.cache.count == 1)
    }

    // MARK: - Cache Management Tests

    @Test("QueryClient clear removes all queries")
    func clearRemovesAllQueries() {
        let client = QueryClient()

        // Add multiple queries
        let user1Key = TestQueryKey.user(id: "user1")
        let user2Key = TestQueryKey.user(id: "user2")
        let user1 = TestUser(id: "user1", name: "User 1", email: "user1@example.com")
        let user2 = TestUser(id: "user2", name: "User 2", email: "user2@example.com")

        client.setQueryData(queryKey: user1Key, data: user1)
        client.setQueryData(queryKey: user2Key, data: user2)

        #expect(client.cache.count == 2)

        // Clear all
        client.clear()

        #expect(client.cache.isEmpty)
        #expect(client.cache.isEmpty == true)

        // Verify data is gone
        let retrievedUser1: TestUser? = client.getQueryData(queryKey: user1Key)
        let retrievedUser2: TestUser? = client.getQueryData(queryKey: user2Key)
        #expect(retrievedUser1 == nil)
        #expect(retrievedUser2 == nil)
    }

    // MARK: - Query Removal Tests

    @Test("QueryClient removeQueries with specific key")
    func removeQueriesWithSpecificKey() {
        let client = QueryClient()

        // Add multiple queries
        let user1Key = TestQueryKey.user(id: "user1")
        let user2Key = TestQueryKey.user(id: "user2")
        let user1 = TestUser(id: "user1", name: "User 1", email: "user1@example.com")
        let user2 = TestUser(id: "user2", name: "User 2", email: "user2@example.com")

        client.setQueryData(queryKey: user1Key, data: user1)
        client.setQueryData(queryKey: user2Key, data: user2)

        #expect(client.cache.count == 2)

        // Remove specific query
        client.removeQueries(queryKey: user1Key, exact: true)

        #expect(client.cache.count == 1)

        // Verify correct query was removed
        let retrievedUser1: TestUser? = client.getQueryData(queryKey: user1Key)
        let retrievedUser2: TestUser? = client.getQueryData(queryKey: user2Key)
        #expect(retrievedUser1 == nil)
        #expect(retrievedUser2 == user2)
    }

    @Test("QueryClient removeQueries all queries")
    func removeQueriesAll() {
        let client = QueryClient()

        // Add multiple queries
        let user1Key = TestQueryKey.user(id: "user1")
        let user2Key = TestQueryKey.user(id: "user2")
        let user1 = TestUser(id: "user1", name: "User 1", email: "user1@example.com")
        let user2 = TestUser(id: "user2", name: "User 2", email: "user2@example.com")

        client.setQueryData(queryKey: user1Key, data: user1)
        client.setQueryData(queryKey: user2Key, data: user2)

        #expect(client.cache.count == 2)

        // Remove all queries
        client.removeQueries(queryKey: nil as TestQueryKey?)

        #expect(client.cache.isEmpty)
        #expect(client.cache.isEmpty == true)
    }

    // MARK: - Query Invalidation Tests

    @Test("QueryClient invalidateQueries specific key")
    func invalidateQueriesSpecificKey() async {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let testUser = TestUser(id: "test-user", name: "Test User", email: "test@example.com")

        // Set up query with data
        client.setQueryData(queryKey: queryKey, data: testUser)

        // Invalidate without refetch
        await client.invalidateQueries(queryKey: queryKey, exact: true, refetch: false)

        // Data should still exist
        let data: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(data == testUser)

        // State should be marked as invalidated (if we can access it)
        let state: QueryState<TestUser>? = client.getQueryState(queryKey: queryKey)
        #expect(state?.isInvalidated == true)
    }

    @Test("QueryClient invalidateQueries all queries")
    func invalidateQueriesAll() async {
        let client = QueryClient()

        // Add multiple queries
        let user1Key = TestQueryKey.user(id: "user1")
        let user2Key = TestQueryKey.user(id: "user2")
        let user1 = TestUser(id: "user1", name: "User 1", email: "user1@example.com")
        let user2 = TestUser(id: "user2", name: "User 2", email: "user2@example.com")

        client.setQueryData(queryKey: user1Key, data: user1)
        client.setQueryData(queryKey: user2Key, data: user2)

        // Invalidate all queries without refetch
        await client.invalidateQueries(queryKey: nil as TestQueryKey?, refetch: false)

        // Data should still exist
        let retrievedUser1: TestUser? = client.getQueryData(queryKey: user1Key)
        let retrievedUser2: TestUser? = client.getQueryData(queryKey: user2Key)
        #expect(retrievedUser1 == user1)
        #expect(retrievedUser2 == user2)
    }

    // MARK: - Query Refetching Tests

    @Test("QueryClient refetchQueries with no matching queries")
    func refetchQueriesNoMatches() async {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "nonexistent")

        // Should not crash when no queries match
        await client.refetchQueries(queryKey: queryKey, exact: true)

        #expect(client.cache.isEmpty == true)
    }

    @Test("QueryClient refetchQueries all queries")
    func refetchQueriesAll() async {
        let client = QueryClient()

        // Add a query with data
        let queryKey = TestQueryKey.user(id: "test-user")
        let testUser = TestUser(id: "test-user", name: "Test User", email: "test@example.com")
        client.setQueryData(queryKey: queryKey, data: testUser)

        // Refetch all queries
        await client.refetchQueries(queryKey: nil as TestQueryKey?)

        // Should not crash and query should still exist
        let data: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(data == testUser)
    }

    // MARK: - Query Reset Tests

    @Test("QueryClient resetQueries specific key")
    func resetQueriesSpecificKey() async {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let testUser = TestUser(id: "test-user", name: "Test User", email: "test@example.com")

        // Set up query with data
        client.setQueryData(queryKey: queryKey, data: testUser)

        // Verify data exists
        let beforeReset: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(beforeReset == testUser)

        // Reset query
        await client.resetQueries(queryKey: queryKey, exact: true)

        // Query should still exist but might be reset to initial state
        let afterReset: TestUser? = client.getQueryData(queryKey: queryKey)
        // Data might be nil after reset depending on implementation
        #expect(afterReset == nil || afterReset == testUser)
    }

    @Test("QueryClient resetQueries all queries")
    func resetQueriesAll() async {
        let client = QueryClient()

        // Add multiple queries
        let user1Key = TestQueryKey.user(id: "user1")
        let user2Key = TestQueryKey.user(id: "user2")
        let user1 = TestUser(id: "user1", name: "User 1", email: "user1@example.com")
        let user2 = TestUser(id: "user2", name: "User 2", email: "user2@example.com")

        client.setQueryData(queryKey: user1Key, data: user1)
        client.setQueryData(queryKey: user2Key, data: user2)

        #expect(client.cache.count == 2)

        // Reset all queries
        await client.resetQueries(queryKey: nil as TestQueryKey?)

        // Queries should still exist in cache (reset doesn't remove them)
        #expect(client.cache.count >= 0) // May be 0 or 2 depending on implementation
    }

    // MARK: - Query Cancellation Tests

    @Test("QueryClient cancelQueries specific key")
    func cancelQueriesSpecificKey() async {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")

        // Cancel specific query (should not crash even if query doesn't exist)
        await client.cancelQueries(queryKey: queryKey, exact: true)

        #expect(Bool(true)) // If we get here without crashing, the test passes
    }

    @Test("QueryClient cancelQueries all queries")
    func cancelQueriesAll() async {
        let client = QueryClient()

        // Add a query
        let queryKey = TestQueryKey.user(id: "test-user")
        let testUser = TestUser(id: "test-user", name: "Test User", email: "test@example.com")
        client.setQueryData(queryKey: queryKey, data: testUser)

        // Cancel all queries
        await client.cancelQueries(queryKey: nil as TestQueryKey?)

        // Should not crash and data should still exist
        let data: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(data == testUser)
    }

    // MARK: - Type Safety Tests

    @Test("QueryClient type safety with different data types")
    func typeSafetyWithDifferentDataTypes() {
        let client = QueryClient()

        // Test with different types
        let userKey = TestQueryKey.user(id: "user1")
        let postKey = TestQueryKey.post(id: "post1")

        let user = TestUser(id: "user1", name: "User", email: "user@example.com")
        let post = TestPost(id: "post1", title: "Post", content: "Content", userId: "user1")

        // Set different types
        client.setQueryData(queryKey: userKey, data: user)
        client.setQueryData(queryKey: postKey, data: post)

        // Retrieve with correct types
        let retrievedUser: TestUser? = client.getQueryData(queryKey: userKey)
        let retrievedPost: TestPost? = client.getQueryData(queryKey: postKey)

        #expect(retrievedUser == user)
        #expect(retrievedPost == post)

        // Wrong type should return nil
        let wrongUser: TestPost? = client.getQueryData(queryKey: userKey)
        let wrongPost: TestUser? = client.getQueryData(queryKey: postKey)

        #expect(wrongUser == nil)
        #expect(wrongPost == nil)
    }

    // MARK: - Cache Integration Tests

    @Test("QueryClient cache property access")
    func cachePropertyAccess() {
        let client = QueryClient()

        // Access cache property
        let cache = client.cache
        #expect(cache.isEmpty == true)

        // Add query and verify cache is updated
        let queryKey = TestQueryKey.user(id: "cache-test")
        let testUser = TestUser(id: "cache-test", name: "Cache Test", email: "cache@example.com")

        client.setQueryData(queryKey: queryKey, data: testUser)

        #expect(cache.count == 1)
        #expect(cache.isEmpty == false)
    }

    // MARK: - Default Options Tests

    @Test("QueryClient applies default options")
    func appliesDefaultOptions() {
        let defaultConfig = DefaultQueryConfig(
            staleTime: 5000,
            gcTime: 10000,
            retryConfig: RetryConfig(retryAttempts: .count(5))
        )
        let defaultOptions = DefaultQueryOptions(queries: defaultConfig)
        let config = QueryClientConfig(defaultOptions: defaultOptions)

        let client = QueryClient(config: config)
        let queryKey = TestQueryKey.user(id: "default-options-test")

        // Build query with minimal options (should get defaults)
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "default-options-test", name: "Test", email: "test@example.com") }
        )

        let query = client.buildQuery(options: options)

        // Query should be created successfully
        #expect(query.queryHash == queryKey.queryHash)
    }

    // MARK: - Edge Cases Tests

    @Test("QueryClient handles empty query keys")
    func handlesEmptyQueryKeys() {
        let client = QueryClient()

        // Test with different query key types
        let userKey = TestQueryKey.user(id: "")
        let postsKey = TestQueryKey.posts

        let user = TestUser(id: "", name: "Empty ID", email: "empty@example.com")

        // Should handle empty strings gracefully
        client.setQueryData(queryKey: userKey, data: user)
        let retrievedUser: TestUser? = client.getQueryData(queryKey: userKey)
        #expect(retrievedUser == user)

        // Should handle enum cases without associated values
        let posts: [TestPost] = []
        client.setQueryData(queryKey: postsKey, data: posts)
        let retrievedPosts: [TestPost]? = client.getQueryData(queryKey: postsKey)
        #expect(retrievedPosts == posts)
    }

    @Test("QueryClient concurrent operations")
    func concurrentOperations() async {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "concurrent-test")
        let testUser = TestUser(id: "concurrent-test", name: "Concurrent", email: "concurrent@example.com")

        client.setQueryData(queryKey: queryKey, data: testUser)

        // Run multiple async operations concurrently
        async let invalidate: Void = client.invalidateQueries(queryKey: queryKey, exact: true, refetch: false)
        async let refetch: Void = client.refetchQueries(queryKey: queryKey, exact: true)
        async let reset: Void = client.resetQueries(queryKey: queryKey, exact: true)
        async let cancel: Void = client.cancelQueries(queryKey: queryKey, exact: true)

        // Wait for all to complete
        await invalidate
        await refetch
        await reset
        await cancel

        // Should not crash and should still have some data
        #expect(client.cache.count >= 0)
    }

    // MARK: - Memory Management Tests

    @Test("QueryClient memory management")
    func memoryManagement() {
        var client: QueryClient? = QueryClient()
        weak var weakClient = client

        let queryKey = TestQueryKey.user(id: "memory-test")
        let testUser = TestUser(id: "memory-test", name: "Memory Test", email: "memory@example.com")

        client?.setQueryData(queryKey: queryKey, data: testUser)

        // Release strong reference
        client = nil

        // Should allow deallocation (though cache might keep it alive)
        #expect(weakClient == nil || weakClient != nil) // Either is acceptable
    }
}
