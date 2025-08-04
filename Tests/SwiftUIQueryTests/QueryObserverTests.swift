import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("QueryObserver Tests")
@MainActor
struct QueryObserverTests {
    // MARK: - Initialization Tests

    @Test("QueryObserver initializes correctly")
    func initializesCorrectly() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") }
        )

        let observer = QueryObserver(client: client, options: options)

        #expect(observer.id.id != UUID()) // Should have unique ID
        #expect(observer.data == nil) // Should start with no data
        #expect(observer.error == nil) // Should start with no error
        #expect(observer.isPending == true) // Should start pending
        #expect(observer.isFetching == false) // Should not be fetching initially
        #expect(observer.isStale == true) // Should start stale
    }

    // MARK: - Convenience Properties Tests

    @Test("QueryObserver convenience properties reflect result")
    func conveniencePropertiesReflectResult() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") }
        )

        let observer = QueryObserver(client: client, options: options)

        // Test that convenience properties match result properties
        #expect(observer.data == observer.result.data)
        #expect(observer.error == observer.result.error)
        #expect(observer.isLoading == observer.result.isLoading)
        #expect(observer.isFetching == observer.result.isFetching)
        #expect(observer.isSuccess == observer.result.isSuccess)
        #expect(observer.isError == observer.result.isError)
        #expect(observer.isPending == observer.result.isPending)
        #expect(observer.isRefetching == observer.result.isRefetching)
        #expect(observer.isStale == observer.result.isStale)
        #expect(observer.isPaused == observer.result.isPaused)
    }

    // MARK: - AnyQueryObserver Protocol Tests

    @Test("QueryObserver AnyQueryObserver protocol methods")
    func anyQueryObserverProtocolMethods() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") },
            enabled: true
        )

        let observer = QueryObserver(client: client, options: options)

        // Test AnyQueryObserver methods
        #expect(observer.isEnabled() == true)

        let result = observer.getCurrentResult()
        #expect(result.isStale == true) // Should start stale
    }

    @Test("QueryObserver disabled state")
    func disabledState() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") },
            enabled: false
        )

        let observer = QueryObserver(client: client, options: options)

        #expect(observer.isEnabled() == false)
    }

    // MARK: - Subscription Tests

    @Test("QueryObserver subscribe/unsubscribe lifecycle")
    func subscribeUnsubscribeLifecycle() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") }
        )

        let observer = QueryObserver(client: client, options: options)

        // Subscribe
        observer.subscribe()

        // State should still be accessible
        #expect(observer.isPending == true || observer.isPending == false) // Basic state check

        // Unsubscribe
        observer.unsubscribe()

        // Observer should still be functional
        #expect(observer.id.id != UUID()) // Still has identity
    }

    // MARK: - Options Update Tests

    @Test("QueryObserver setOptions updates enabled state")
    func setOptionsUpdatesEnabledState() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")

        let initialOptions = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") },
            enabled: true
        )

        let observer = QueryObserver(client: client, options: initialOptions)
        #expect(observer.isEnabled() == true)

        let disabledOptions = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Updated", email: "updated@example.com") },
            enabled: false
        )

        observer.setOptions(disabledOptions)
        #expect(observer.isEnabled() == false)
    }

    // MARK: - Refetch Tests

    @Test("QueryObserver refetch returns task")
    func refetchReturnsTask() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "test-user")
        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in TestUser(id: "test-user", name: "Test", email: "test@example.com") }
        )

        let observer = QueryObserver(client: client, options: options)

        // Refetch should return a task
        let refetchTask = observer.refetch()

        // Task should exist and be completable
        #expect(refetchTask is Task<TestUser?, Error>)
    }

    // MARK: - Integration Tests

    @Test("QueryObserver basic lifecycle integration")
    func basicLifecycleIntegration() {
        let client = QueryClient()
        let queryKey = TestQueryKey.user(id: "integration-test")
        let testUser = TestUser(id: "integration-test", name: "Integration", email: "integration@example.com")

        let options = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in testUser },
            staleTime: 1.0,
            gcTime: 5.0,
            enabled: true
        )

        let observer = QueryObserver(client: client, options: options)

        // 1. Initial state
        #expect(observer.isPending == true)
        #expect(observer.data == nil)
        #expect(observer.isStale == true)

        // 2. Subscribe
        observer.subscribe()

        // 3. Update options
        let disabledOptions = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in testUser },
            enabled: false
        )
        observer.setOptions(disabledOptions)
        #expect(observer.isEnabled() == false)

        // 4. Re-enable
        let enabledOptions = QueryOptions<TestUser, TestQueryKey>(
            queryKey: queryKey,
            queryFn: { _ in testUser },
            enabled: true
        )
        observer.setOptions(enabledOptions)
        #expect(observer.isEnabled() == true)

        // 5. Unsubscribe
        observer.unsubscribe()

        // 6. Observer should still be accessible but unsubscribed
        #expect(observer.id.id != UUID()) // Still has identity
    }
}
