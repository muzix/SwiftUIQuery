import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("Foundational Types Tests")
@MainActor
struct FoundationalTypesTests {
    // MARK: - QueryKey Tests

    @Test("ArrayQueryKey creates consistent hashes")
    func arrayQueryKeyHashing() {
        let key1 = ArrayQueryKey("users", "123")
        let key2 = ArrayQueryKey("users", "123")
        let key3 = ArrayQueryKey("users", "456")

        #expect(key1.queryHash == key2.queryHash)
        #expect(key1.queryHash != key3.queryHash)
        #expect(key1 == key2)
        #expect(key1 != key3)
    }

    @Test("GenericQueryKey works with different types")
    func genericQueryKeyTypes() {
        let stringKey = GenericQueryKey("test")
        let intKey = GenericQueryKey(42)
        let arrayKey = GenericQueryKey(["a", "b", "c"])

        #expect(stringKey.value == "test")
        #expect(intKey.value == 42)
        #expect(arrayKey.value == ["a", "b", "c"])

        // Different types should have different hashes
        #expect(stringKey.queryHash != intKey.queryHash)
    }

    // MARK: - Status Enum Tests

    @Test("QueryStatus enum values")
    func queryStatusValues() {
        #expect(QueryStatus.pending.rawValue == "pending")
        #expect(QueryStatus.error.rawValue == "error")
        #expect(QueryStatus.success.rawValue == "success")
    }

    @Test("FetchStatus enum values")
    func fetchStatusValues() {
        #expect(FetchStatus.fetching.rawValue == "fetching")
        #expect(FetchStatus.paused.rawValue == "paused")
        #expect(FetchStatus.idle.rawValue == "idle")
    }

    // MARK: - RetryConfig Tests

    @Test("RetryConfig default behavior")
    func retryConfigDefaults() {
        let config = RetryConfig()

        // Should retry up to 3 times by default
        #expect(config.shouldRetry(failureCount: 0, error: SimpleTestError.generic))
        #expect(config.shouldRetry(failureCount: 2, error: SimpleTestError.generic))
        #expect(!config.shouldRetry(failureCount: 3, error: SimpleTestError.generic))
    }

    @Test("RetryConfig exponential backoff")
    func retryConfigBackoff() {
        let config = RetryConfig()

        // Test exponential backoff delays
        let delay1 = config.delayForAttempt(failureCount: 0, error: SimpleTestError.generic)
        let delay2 = config.delayForAttempt(failureCount: 1, error: SimpleTestError.generic)
        let delay3 = config.delayForAttempt(failureCount: 5, error: SimpleTestError.generic)

        #expect(delay1 == 1.0) // 2^0 = 1
        #expect(delay2 == 2.0) // 2^1 = 2
        #expect(delay3 == 30.0) // Capped at 30 seconds
    }

    @Test("RetryConfig custom configurations")
    func retryConfigCustom() {
        let neverRetry = RetryConfig(retryAttempts: .never)
        let infiniteRetry = RetryConfig(retryAttempts: .infinite)
        let fixedDelay = RetryConfig(retryDelay: .fixed(5.0))

        #expect(!neverRetry.shouldRetry(failureCount: 0, error: SimpleTestError.generic))
        #expect(infiniteRetry.shouldRetry(failureCount: 100, error: SimpleTestError.generic))
        #expect(fixedDelay.delayForAttempt(failureCount: 3, error: SimpleTestError.generic) == 5.0)
    }

    // MARK: - RefetchTriggers Tests

    @Test("RefetchTriggers default configuration")
    func refetchTriggersDefaults() {
        let defaultConfig = RefetchTriggers.default

        #expect(defaultConfig.onAppear)
        #expect(defaultConfig.onAppForeground)
        #expect(defaultConfig.onNetworkReconnect)
    }

    @Test("RefetchTriggers never configuration")
    func refetchTriggersNever() {
        let neverConfig = RefetchTriggers.never

        #expect(!neverConfig.onAppear)
        #expect(!neverConfig.onAppForeground)
        #expect(!neverConfig.onNetworkReconnect)
    }

    @Test("RefetchOnAppear enum values")
    func refetchOnAppearValues() {
        // Test that enum values exist and can be compared
        let always = RefetchOnAppear.always
        let ifStale = RefetchOnAppear.ifStale
        let never = RefetchOnAppear.never

        #expect(always != ifStale)
        #expect(ifStale != never)
        #expect(always != never)
    }

    // MARK: - QueryState Tests

    @Test("QueryState default initialization")
    func queryStateDefaults() {
        let state = QueryState<String>.defaultState()

        #expect(state.data == nil)
        #expect(state.dataUpdateCount == 0)
        #expect(state.error == nil)
        #expect(state.status == QueryStatus.pending)
        #expect(state.fetchStatus == FetchStatus.idle)
        #expect(!state.isInvalidated)
    }

    @Test("QueryState with initial data")
    func queryStateWithData() {
        let state = QueryState<String>(data: "test data")

        #expect(state.data == "test data")
        #expect(state.status == .success)
        #expect(state.dataUpdateCount == 0)
        #expect(state.dataUpdatedAt > 0)
    }

    @Test("QueryState data updates")
    func queryStateDataUpdates() {
        let initialState = QueryState<String>.defaultState()
        let updatedState = initialState.withData("new data")

        #expect(updatedState.data == "new data")
        #expect(updatedState.status == .success)
        #expect(updatedState.dataUpdateCount == 1)
        #expect(updatedState.error == nil) // Error should be cleared
        #expect(updatedState.fetchFailureCount == 0) // Failure count should reset
    }

    @Test("QueryState error updates")
    func queryStateErrorUpdates() {
        let initialState = QueryState<String>.defaultState()
        let errorState = initialState.withError(QueryError.networkError(URLError(.notConnectedToInternet)))

        #expect(errorState.error == QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(errorState.status == QueryStatus.error)
        #expect(errorState.errorUpdateCount == 1)
        #expect(errorState.fetchFailureCount == 1)
    }

    @Test("QueryState invalidation")
    func queryStateInvalidation() {
        let state = QueryState<String>(data: "test")
        let invalidatedState = state.invalidated()

        #expect(invalidatedState.isInvalidated)
        #expect(invalidatedState.data == "test") // Data should remain
    }

    // MARK: - InfiniteData Tests

    @Test("InfiniteData initialization")
    func infiniteDataInit() {
        let data = InfiniteData<[String], Int>()

        #expect(data.isEmpty)
        #expect(data.pageCount == 0)
        #expect(data.lastPageParam == nil)
        #expect(data.firstPageParam == nil)
    }

    @Test("InfiniteData page management")
    func infiniteDataPageManagement() {
        let data = InfiniteData<[String], Int>()
        let withPage1 = data.appendPage(["item1", "item2"], param: 1)
        let withPage2 = withPage1.appendPage(["item3", "item4"], param: 2)

        #expect(withPage2.pageCount == 2)
        #expect(withPage2.lastPageParam == 2)
        #expect(withPage2.firstPageParam == 1)
        #expect(!withPage2.isEmpty)
    }

    @Test("InfiniteData prepend pages")
    func infiniteDataPrepend() {
        let data = InfiniteData<[String], Int>()
            .appendPage(["item3", "item4"], param: 2)
            .prependPage(["item1", "item2"], param: 1)

        #expect(data.pageCount == 2)
        #expect(data.firstPageParam == 1)
        #expect(data.lastPageParam == 2)
        #expect(data.pages[0] == ["item1", "item2"])
        #expect(data.pages[1] == ["item3", "item4"])
    }

    @Test("InfiniteData page limiting")
    func infiniteDataLimiting() {
        let data = InfiniteData<[String], Int>()
            .appendPage(["page1"], param: 1)
            .appendPage(["page2"], param: 2)
            .appendPage(["page3"], param: 3)
            .limitPages(to: 2)

        #expect(data.pageCount == 2)
        #expect(data.pages == [["page1"], ["page2"]])
        #expect(data.pageParams == [1, 2])
    }

    @Test("InfiniteData flatMap")
    func infiniteDataFlatMap() {
        let data = InfiniteData<[String], Int>()
            .appendPage(["item1", "item2"], param: 1)
            .appendPage(["item3", "item4"], param: 2)

        let flattened: [String] = data.flatMap()
        #expect(flattened == ["item1", "item2", "item3", "item4"])
    }

    // MARK: - QueryError Tests

    @Test("QueryError initialization")
    func queryErrorInit() {
        let error = QueryError(message: "Test error", code: "TEST_001")

        #expect(error.message == "Test error")
        #expect(error.code == "TEST_001")
        #expect(error.underlyingError == nil)
    }

    @Test("QueryError with underlying error")
    func queryErrorWithUnderlying() {
        let underlying = QueryError.networkError(URLError(.notConnectedToInternet))
        let error = QueryError(message: "Network failed", underlyingError: underlying)

        #expect(error.message == "Network failed")
        #expect(error.underlyingError != nil)
    }

    // MARK: - QueryObserverIdentifier Tests

    @Test("QueryObserverIdentifier uniqueness")
    func queryObserverIdentifierUniqueness() {
        let id1 = QueryObserverIdentifier()
        let id2 = QueryObserverIdentifier()

        #expect(id1 != id2)
        #expect(id1.id != id2.id)
    }

    // MARK: - NetworkMode Tests

    @Test("NetworkMode enum values")
    func networkModeValues() {
        #expect(NetworkMode.online.rawValue == "online")
        #expect(NetworkMode.always.rawValue == "always")
        #expect(NetworkMode.offlineFirst.rawValue == "offlineFirst")
    }

    // MARK: - Mutex Tests

    @Test("Mutex basic lock/unlock")
    func mutexBasicLockUnlock() async {
        let mutex = Mutex()

        // Should not be locked initially
        let initiallyLocked = await mutex.isCurrentlyLocked
        #expect(!initiallyLocked)

        // Lock the mutex
        await mutex.lock()
        let lockedState = await mutex.isCurrentlyLocked
        #expect(lockedState)

        // Unlock the mutex
        await mutex.unlock()
        let unlockedState = await mutex.isCurrentlyLocked
        #expect(!unlockedState)
    }

    @Test("Mutex withLock convenience method")
    func mutexWithLock() async throws {
        let mutex = Mutex()
        let counter = Counter()

        let result = await mutex.withLock {
            await counter.increment()
            return await counter.value * 2
        }

        #expect(result == 2)
        let finalCounterValue = await counter.value
        #expect(finalCounterValue == 1)

        // Mutex should be unlocked after operation
        let finalState = await mutex.isCurrentlyLocked
        #expect(!finalState)
    }

    @Test("Mutex concurrent access serialization")
    func mutexConcurrentAccess() async {
        let mutex = Mutex()
        let operations = OperationsTracker()

        // Start multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 5 {
                group.addTask {
                    await mutex.withLock {
                        await operations.addOperation(i)
                        // Small delay to ensure serialization
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                }
            }
        }

        // All operations should have completed
        let finalOperations = await operations.getOperations()
        #expect(finalOperations.count == 5)
        // Operations should contain all values 0-4 (order may vary)
        #expect(Set(finalOperations) == Set(0 ..< 5))
    }

    @Test("Mutex error handling in withLock")
    func mutexErrorHandling() async {
        let mutex = Mutex()

        do {
            try await mutex.withLock {
                throw QueryError.networkError(URLError(.notConnectedToInternet))
            }
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is QueryError)
        }

        // Mutex should be unlocked even after error
        let finalState = await mutex.isCurrentlyLocked
        #expect(!finalState)
    }

    // MARK: - QueryCacheEvent Tests

    @Test("QueryCacheEvent enum values")
    func queryCacheEventValues() {
        let addedEvent = QueryCacheEvent.added(queryHash: "test-hash")
        let removedEvent = QueryCacheEvent.removed(queryHash: "test-hash")
        let updatedEvent = QueryCacheEvent.updated(queryHash: "test-hash")
        let clearedEvent = QueryCacheEvent.cleared

        // Verify events can be created and are different
        switch addedEvent {
        case let .added(hash):
            #expect(hash == "test-hash")
        default:
            #expect(Bool(false), "Should be added event")
        }

        switch removedEvent {
        case let .removed(hash):
            #expect(hash == "test-hash")
        default:
            #expect(Bool(false), "Should be removed event")
        }

        switch updatedEvent {
        case let .updated(hash):
            #expect(hash == "test-hash")
        default:
            #expect(Bool(false), "Should be updated event")
        }

        switch clearedEvent {
        case .cleared:
            break // Success
        default:
            #expect(Bool(false), "Should be cleared event")
        }
    }

    // MARK: - QueryCache Tests

    @Test("QueryCache initialization")
    @MainActor
    func queryCacheInit() {
        let cache = QueryCache()

        #expect(cache.isEmpty)
        #expect(cache.isEmpty)
        #expect(cache.allQueries.isEmpty)
        #expect(cache.queryHashes.isEmpty)
    }

    @Test("QueryCache add and retrieve queries")
    @MainActor
    func queryCacheAddRetrieve() {
        let cache = QueryCache()
        let mockQuery = MockQuery(queryHash: "test-query", isStale: false)

        // Add query
        cache.add(mockQuery)

        #expect(!cache.isEmpty)
        #expect(cache.count == 1)
        #expect(cache.has(queryHash: "test-query"))

        // Retrieve query
        let retrieved = cache.get(queryHash: "test-query")
        #expect(retrieved?.queryHash == "test-query")

        // Check collections
        #expect(cache.allQueries.count == 1)
        #expect(cache.queryHashes.contains("test-query"))
    }

    @Test("QueryCache remove queries")
    @MainActor
    func queryCacheRemove() {
        let cache = QueryCache()
        let mockQuery = MockQuery(queryHash: "test-query", isStale: false)

        // Add then remove
        cache.add(mockQuery)
        #expect(cache.count == 1)

        cache.remove(mockQuery)
        #expect(cache.isEmpty)
        #expect(!cache.has(queryHash: "test-query"))
        #expect(cache.get(queryHash: "test-query") == nil)
    }

    @Test("QueryCache clear all queries")
    @MainActor
    func queryCacheClear() {
        let cache = QueryCache()
        let query1 = MockQuery(queryHash: "query-1", isStale: false)
        let query2 = MockQuery(queryHash: "query-2", isStale: true)

        // Add multiple queries
        cache.add(query1)
        cache.add(query2)
        #expect(cache.count == 2)

        // Clear all
        cache.clear()
        #expect(cache.isEmpty)
        #expect(cache.allQueries.isEmpty)
        #expect(cache.queryHashes.isEmpty)
    }

    @Test("QueryCache find operations")
    @MainActor
    func queryCacheFindOperations() {
        let cache = QueryCache()
        let staleQuery = MockQuery(queryHash: "stale-query", isStale: true)
        let freshQuery = MockQuery(queryHash: "fresh-query", isStale: false)

        cache.add(staleQuery)
        cache.add(freshQuery)

        // Find all stale queries
        let staleQueries = cache.findAll { $0.isStale }
        #expect(staleQueries.count == 1)
        #expect(staleQueries.first?.queryHash == "stale-query")

        // Find first fresh query
        let firstFresh = cache.find { !$0.isStale }
        #expect(firstFresh?.queryHash == "fresh-query")

        // Find non-existent
        let nonExistent = cache.find { $0.queryHash == "does-not-exist" }
        #expect(nonExistent == nil)
    }

    @Test("QueryCache event subscription")
    @MainActor
    func queryCacheEventSubscription() async {
        let cache = QueryCache()
        let eventTracker = EventTracker()

        // Subscribe to events
        let unsubscribe = cache.subscribe { event in
            Task {
                await eventTracker.addEvent(event)
            }
        }

        let mockQuery = MockQuery(queryHash: "test-query", isStale: false)

        // Perform operations that should trigger events
        cache.add(mockQuery)
        cache.remove(mockQuery)
        cache.clear()

        // Small delay to allow async event processing
        try? await Task.sleep(for: .milliseconds(10))

        let receivedEvents = await eventTracker.getEvents()

        // Verify events were received
        #expect(receivedEvents.count == 3)

        // Check event types
        switch receivedEvents[0] {
        case let .added(hash):
            #expect(hash == "test-query")
        default:
            #expect(Bool(false), "First event should be added")
        }

        switch receivedEvents[1] {
        case let .removed(hash):
            #expect(hash == "test-query")
        default:
            #expect(Bool(false), "Second event should be removed")
        }

        switch receivedEvents[2] {
        case .cleared:
            break // Success
        default:
            #expect(Bool(false), "Third event should be cleared")
        }

        // Test unsubscription
        unsubscribe()
        await eventTracker.clearEvents()

        cache.add(MockQuery(queryHash: "another-query", isStale: false))
        try? await Task.sleep(for: .milliseconds(10))

        let eventsAfterUnsubscribe = await eventTracker.getEvents()
        #expect(eventsAfterUnsubscribe.isEmpty, "Should not receive events after unsubscribe")
    }

    @Test("QueryCache thread-safe operations")
    @MainActor
    func queryCacheThreadSafety() async {
        let cache = QueryCache()

        // Test that withLock provides proper synchronization
        let result = await cache.withLock {
            let query = MockQuery(queryHash: "test-query", isStale: false)
            cache.add(query)
            return cache.has(queryHash: "test-query")
        }

        #expect(result)
        #expect(cache.count == 1)

        // Test multiple sequential operations
        for i in 1 ..< 5 {
            await cache.withLock {
                let query = MockQuery(queryHash: "query-\(i)", isStale: false)
                cache.add(query)
            }
        }

        #expect(cache.count == 5)
    }
}

// MARK: - Test Helpers

enum SimpleTestError: Error, Sendable, Codable, Equatable {
    case generic
    case network
    case timeout
}

/// Mock implementation of AnyQuery for testing
struct MockQuery: AnyQuery {
    let queryHash: String
    let isStale: Bool
    let lastUpdated: Date?
    let isActive: Bool
    let gcTime: TimeInterval

    var isEligibleForGC: Bool {
        // Mock implementation: not active and past gcTime
        guard !isActive, let lastUpdated else { return !isActive }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdated)
        return timeSinceUpdate >= gcTime
    }

    init(
        queryHash: String,
        isStale: Bool,
        lastUpdated: Date? = Date(),
        isActive: Bool = false,
        gcTime: TimeInterval = defaultGcTime
    ) {
        self.queryHash = queryHash
        self.isStale = isStale
        self.lastUpdated = lastUpdated
        self.isActive = isActive
        self.gcTime = gcTime
    }
}

/// Thread-safe counter for testing
actor Counter {
    private var _value = 0

    var value: Int {
        _value
    }

    func increment() {
        _value += 1
    }
}

/// Thread-safe operations tracker for testing
actor OperationsTracker {
    private var operations: [Int] = []

    func addOperation(_ operation: Int) {
        operations.append(operation)
    }

    func getOperations() -> [Int] {
        operations
    }
}

/// Thread-safe event tracker for testing
actor EventTracker {
    private var events: [QueryCacheEvent] = []

    func addEvent(_ event: QueryCacheEvent) {
        events.append(event)
    }

    func getEvents() -> [QueryCacheEvent] {
        events
    }

    func clearEvents() {
        events.removeAll()
    }
}

/// Thread-safe results tracker for testing
actor ResultsTracker {
    private var results: [Bool] = []

    func addResult(_ result: Bool) {
        results.append(result)
    }

    func getResults() -> [Bool] {
        results
    }
}
