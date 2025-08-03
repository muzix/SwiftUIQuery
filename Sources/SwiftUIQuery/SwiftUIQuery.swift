// SwiftUI Query - A Swift implementation of TanStack Query for SwiftUI
// Foundational Types and Protocols

import Foundation
import Perception

// MARK: - QueryKey Protocol

/// A protocol that represents a unique identifier for queries
/// Equivalent to TanStack Query's QueryKey (ReadonlyArray<unknown>)
public protocol QueryKey: Sendable, Hashable, Codable {
    /// Convert the query key to a string hash for identification
    var queryHash: String { get }
}

/// Default QueryKey implementation using arrays of strings
public struct ArrayQueryKey: QueryKey {
    public let components: [String]

    public init(_ components: String...) {
        self.components = components
    }

    public init(_ components: [String]) {
        self.components = components
    }

    public var queryHash: String {
        // Create a deterministic hash similar to TanStack Query's approach
        guard let jsonData = try? JSONEncoder().encode(components.sorted()),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return components.sorted().joined(separator: "|")
        }
        return jsonString
    }
}

/// Generic QueryKey implementation for any Codable type
public struct GenericQueryKey<T: Sendable & Codable & Hashable>: QueryKey {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public var queryHash: String {
        guard let jsonData = try? JSONEncoder().encode(value),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return String(describing: value)
        }
        return jsonString
    }
}

// MARK: - Query Status & Fetch Status

/// Represents the overall state of query data
/// Equivalent to TanStack Query's QueryStatus
public enum QueryStatus: String, Sendable, Codable {
    /// No cached data, query hasn't completed successfully yet
    case pending
    /// Query attempt resulted in an error
    case error
    /// Query has received a response with no errors
    case success
}

/// Represents the fetching activity state
/// Equivalent to TanStack Query's FetchStatus
public enum FetchStatus: String, Sendable, Codable {
    /// QueryFn is executing (initial load or background refetch)
    case fetching
    /// Query wanted to fetch but has been paused
    case paused
    /// Query is not fetching
    case idle
}

// MARK: - Retry Configuration

/// Function signature for custom retry logic
public typealias ShouldRetryFunction = @Sendable (Int, Error) -> Bool

/// Function signature for custom retry delay
public typealias RetryDelayFunction = @Sendable (Int, Error) -> TimeInterval

/// Configuration for retry behavior
/// Equivalent to TanStack Query's RetryValue and RetryDelayValue
public struct RetryConfig: Sendable, Codable {
    /// Whether to retry, how many times, or custom logic
    public let retryAttempts: RetryAttempts
    /// Delay between retries
    public let retryDelay: RetryDelay

    public init(retryAttempts: RetryAttempts = .count(3), retryDelay: RetryDelay = .exponentialBackoff) {
        self.retryAttempts = retryAttempts
        self.retryDelay = retryDelay
    }

    public enum RetryAttempts: Sendable, Codable {
        case never
        case count(Int)
        case infinite
        // Note: Custom functions cannot be Codable, handled separately
    }

    public enum RetryDelay: Sendable, Codable {
        case fixed(TimeInterval)
        case exponentialBackoff
        // Note: Custom functions cannot be Codable, handled separately
    }

    /// Get the actual retry count for this attempt
    public func shouldRetry(failureCount: Int, error: Error) -> Bool {
        switch retryAttempts {
        case .never:
            return false
        case let .count(max):
            return failureCount < max
        case .infinite:
            return true
        }
    }

    /// Calculate delay for the given failure count
    public func delayForAttempt(failureCount: Int, error: Error) -> TimeInterval {
        switch retryDelay {
        case let .fixed(delay):
            return delay
        case .exponentialBackoff:
            // Match TanStack Query's exponential backoff: Math.min(1000 * 2 ** failureCount, 30000)
            return min(1.0 * pow(2.0, Double(failureCount)), 30.0)
        }
    }
}

// MARK: - Network Mode

/// Configuration for network behavior
/// Equivalent to TanStack Query's NetworkMode
public enum NetworkMode: String, Sendable, Codable {
    /// Only fetch when online (default)
    case online
    /// Fetch regardless of network status
    case always
    /// Pause when offline, resume when online
    case offlineFirst
}

// MARK: - Refetch Configuration

/// Configuration for when to refetch queries in iOS/SwiftUI
/// iOS-specific equivalent to TanStack Query's refetch triggers
public struct RefetchTriggers: Sendable, Codable {
    /// Refetch when view appears (SwiftUI .onAppear)
    public let onAppear: Bool
    /// Refetch when app becomes active from background
    public let onAppForeground: Bool
    /// Refetch when network connectivity is restored
    public let onNetworkReconnect: Bool

    public init(onAppear: Bool = true, onAppForeground: Bool = true, onNetworkReconnect: Bool = true) {
        self.onAppear = onAppear
        self.onAppForeground = onAppForeground
        self.onNetworkReconnect = onNetworkReconnect
    }

    public static let `default` = Self()
    public static let never = Self(onAppear: false, onAppForeground: false, onNetworkReconnect: false)
}

/// Enum specifying when to refetch on view appear
/// Maps to SwiftUI .onAppear behavior
public enum RefetchOnAppear: Sendable, Codable {
    /// Always refetch when view appears
    case always
    /// Only refetch if data is stale when view appears
    case ifStale
    /// Never automatically refetch on view appear
    case never
}

// MARK: - Query Metadata

/// Arbitrary metadata that can be attached to queries
/// Equivalent to TanStack Query's QueryMeta
public typealias QueryMeta = [String: AnyCodable]

/// Helper type for storing any Sendable Codable value in QueryMeta
public struct AnyCodable: Sendable, Codable, Hashable {
    private let stringValue: String
    private let encode: @Sendable (Encoder) throws -> Void

    public init(_ value: some Codable & Sendable) {
        self.stringValue = String(describing: value)
        self.encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedString = try container.decode(String.self)
        self.stringValue = decodedString
        self.encode = { encoder in
            try decodedString.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}

// MARK: - Query Function Types

/// Function signature for query functions
public typealias QueryFunction<TData: Sendable, TKey: QueryKey> = @Sendable (TKey) async throws -> TData

/// Function signature for initial data providers
public typealias InitialDataFunction<TData: Sendable> = @Sendable () -> TData?

// MARK: - Query Options

/// Configuration options for queries
/// Equivalent to TanStack Query's QueryOptions
public struct QueryOptions<TData: Sendable, TError: Error & Sendable & Codable, TKey: QueryKey>: Sendable {
    /// The query key that uniquely identifies this query
    public let queryKey: TKey
    /// The function that will be called to fetch data
    public let queryFn: QueryFunction<TData, TKey>
    /// Configuration for retry behavior
    public let retryConfig: RetryConfig
    /// Network behavior configuration
    public let networkMode: NetworkMode
    /// Time after which data is considered stale (in seconds)
    public let staleTime: TimeInterval
    /// Time after which inactive queries are garbage collected (in seconds)
    public let gcTime: TimeInterval
    /// Configuration for automatic refetching triggers
    public let refetchTriggers: RefetchTriggers
    /// Specific behavior for view appear events
    public let refetchOnAppear: RefetchOnAppear
    /// Initial data to use while loading
    public let initialData: TData?
    /// Function to provide initial data
    public let initialDataFunction: InitialDataFunction<TData>?
    /// Whether to use structural sharing for performance
    public let structuralSharing: Bool
    /// Arbitrary metadata for this query
    public let meta: QueryMeta?
    /// Whether this query is enabled (will fetch automatically)
    public let enabled: Bool

    public init(
        queryKey: TKey,
        queryFn: @escaping QueryFunction<TData, TKey>,
        retryConfig: RetryConfig = RetryConfig(),
        networkMode: NetworkMode = .online,
        staleTime: TimeInterval = 0, // Immediately stale by default
        gcTime: TimeInterval = 5 * 60, // 5 minutes default
        refetchTriggers: RefetchTriggers = .default,
        refetchOnAppear: RefetchOnAppear = .always,
        initialData: TData? = nil,
        initialDataFunction: InitialDataFunction<TData>? = nil,
        structuralSharing: Bool = true,
        meta: QueryMeta? = nil,
        enabled: Bool = true
    ) {
        self.queryKey = queryKey
        self.queryFn = queryFn
        self.retryConfig = retryConfig
        self.networkMode = networkMode
        self.staleTime = staleTime
        self.gcTime = gcTime
        self.refetchTriggers = refetchTriggers
        self.refetchOnAppear = refetchOnAppear
        self.initialData = initialData
        self.initialDataFunction = initialDataFunction
        self.structuralSharing = structuralSharing
        self.meta = meta
        self.enabled = enabled
    }
}

// MARK: - Infinite Query Types

/// Function signature for infinite query functions
public typealias InfiniteQueryFunction<TData: Sendable, TKey: QueryKey, TPageParam: Sendable & Codable> =
    @Sendable (
        TKey,
        TPageParam?
    ) async throws -> TData

/// Function to get the next page parameter
public typealias GetNextPageParamFunction<TData: Sendable, TPageParam: Sendable & Codable> =
    @Sendable ([TData]) -> TPageParam?

/// Function to get the previous page parameter
public typealias GetPreviousPageParamFunction<TData: Sendable, TPageParam: Sendable & Codable> =
    @Sendable ([TData]) -> TPageParam?

/// Configuration options for infinite queries
/// Equivalent to TanStack Query's InfiniteQueryOptions
public struct InfiniteQueryOptions<
    TData: Sendable,
    TError: Error & Sendable & Codable,
    TKey: QueryKey,
    TPageParam: Sendable & Codable
>: Sendable {
    /// The query key that uniquely identifies this query
    public let queryKey: TKey
    /// The function that will be called to fetch data pages
    public let queryFn: InfiniteQueryFunction<TData, TKey, TPageParam>
    /// Function to determine the next page parameter
    public let getNextPageParam: GetNextPageParamFunction<TData, TPageParam>?
    /// Function to determine the previous page parameter
    public let getPreviousPageParam: GetPreviousPageParamFunction<TData, TPageParam>?
    /// Initial page parameter for the first page
    public let initialPageParam: TPageParam?
    /// Maximum number of pages to retain
    public let maxPages: Int?
    /// Configuration for retry behavior
    public let retryConfig: RetryConfig
    /// Network behavior configuration
    public let networkMode: NetworkMode
    /// Time after which data is considered stale (in seconds)
    public let staleTime: TimeInterval
    /// Time after which inactive queries are garbage collected (in seconds)
    public let gcTime: TimeInterval
    /// Configuration for automatic refetching triggers
    public let refetchTriggers: RefetchTriggers
    /// Specific behavior for view appear events
    public let refetchOnAppear: RefetchOnAppear
    /// Whether to use structural sharing for performance
    public let structuralSharing: Bool
    /// Arbitrary metadata for this query
    public let meta: QueryMeta?
    /// Whether this query is enabled (will fetch automatically)
    public let enabled: Bool

    public init(
        queryKey: TKey,
        queryFn: @escaping InfiniteQueryFunction<TData, TKey, TPageParam>,
        getNextPageParam: GetNextPageParamFunction<TData, TPageParam>? = nil,
        getPreviousPageParam: GetPreviousPageParamFunction<TData, TPageParam>? = nil,
        initialPageParam: TPageParam? = nil,
        maxPages: Int? = nil,
        retryConfig: RetryConfig = RetryConfig(),
        networkMode: NetworkMode = .online,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = 5 * 60,
        refetchTriggers: RefetchTriggers = .default,
        refetchOnAppear: RefetchOnAppear = .always,
        structuralSharing: Bool = true,
        meta: QueryMeta? = nil,
        enabled: Bool = true
    ) {
        self.queryKey = queryKey
        self.queryFn = queryFn
        self.getNextPageParam = getNextPageParam
        self.getPreviousPageParam = getPreviousPageParam
        self.initialPageParam = initialPageParam
        self.maxPages = maxPages
        self.retryConfig = retryConfig
        self.networkMode = networkMode
        self.staleTime = staleTime
        self.gcTime = gcTime
        self.refetchTriggers = refetchTriggers
        self.refetchOnAppear = refetchOnAppear
        self.structuralSharing = structuralSharing
        self.meta = meta
        self.enabled = enabled
    }
}

/// Container for infinite query data with pagination support
/// Equivalent to TanStack Query's InfiniteData
public struct InfiniteData<TData: Sendable, TPageParam: Sendable & Codable>: Sendable {
    /// Array of pages containing the actual data
    public let pages: [TData]
    /// Array of page parameters used to fetch each page
    public let pageParams: [TPageParam?]

    public init(pages: [TData] = [], pageParams: [TPageParam?] = []) {
        self.pages = pages
        self.pageParams = pageParams
    }

    /// Add a new page to the end
    public func appendPage(_ page: TData, param: TPageParam?) -> InfiniteData<TData, TPageParam> {
        var newPages = pages
        var newParams = pageParams
        newPages.append(page)
        newParams.append(param)
        return Self(pages: newPages, pageParams: newParams)
    }

    /// Add a new page to the beginning
    public func prependPage(_ page: TData, param: TPageParam?) -> InfiniteData<TData, TPageParam> {
        var newPages = pages
        var newParams = pageParams
        newPages.insert(page, at: 0)
        newParams.insert(param, at: 0)
        return Self(pages: newPages, pageParams: newParams)
    }

    /// Remove pages beyond the specified maximum
    public func limitPages(to maxPages: Int) -> InfiniteData<TData, TPageParam> {
        guard maxPages > 0, pages.count > maxPages else { return self }

        let limitedPages = Array(pages.prefix(maxPages))
        let limitedParams = Array(pageParams.prefix(maxPages))
        return Self(pages: limitedPages, pageParams: limitedParams)
    }

    /// Get the total number of pages
    public var pageCount: Int {
        pages.count
    }

    /// Check if there are any pages
    public var isEmpty: Bool {
        pages.isEmpty
    }

    /// Get the last page parameter (for next page fetching)
    public var lastPageParam: TPageParam? {
        pageParams.last.flatMap(\.self)
    }

    /// Get the first page parameter (for previous page fetching)
    public var firstPageParam: TPageParam? {
        pageParams.first.flatMap(\.self)
    }

    /// Flatten all pages into a single array if TData is a collection
    public func flatMap<Element>() -> [Element] where TData == [Element] {
        pages.flatMap(\.self)
    }
}

// MARK: - Query State

/// Complete state of a query instance
/// Equivalent to TanStack Query's QueryState
/// This is the single source of truth for query state - QueryObserverResult computes derived properties from this
public struct QueryState<TData: Sendable, TError: Error & Sendable & Codable>: Sendable {
    /// The actual data returned by the query function
    public let data: TData?
    /// Number of times data has been updated
    public let dataUpdateCount: Int
    /// Timestamp when data was last updated (milliseconds since epoch)
    public let dataUpdatedAt: Int64
    /// The error object if the query failed
    public let error: TError?
    /// Number of times an error has occurred
    public let errorUpdateCount: Int
    /// Timestamp when error was last updated (milliseconds since epoch)
    public let errorUpdatedAt: Int64
    /// Number of consecutive failures
    public let fetchFailureCount: Int
    /// The failure reason of the last fetch attempt
    public let fetchFailureReason: TError?
    /// Arbitrary metadata from the query function
    public let fetchMeta: QueryMeta?
    /// Whether the query has been invalidated
    public let isInvalidated: Bool
    /// Overall status of the query
    public let status: QueryStatus
    /// Current fetch activity status
    public let fetchStatus: FetchStatus

    public init(
        data: TData? = nil,
        dataUpdateCount: Int = 0,
        dataUpdatedAt: Int64? = nil,
        error: TError? = nil,
        errorUpdateCount: Int = 0,
        errorUpdatedAt: Int64 = 0,
        fetchFailureCount: Int = 0,
        fetchFailureReason: TError? = nil,
        fetchMeta: QueryMeta? = nil,
        isInvalidated: Bool = false,
        status: QueryStatus? = nil,
        fetchStatus: FetchStatus = .idle
    ) {
        self.data = data
        self.dataUpdateCount = dataUpdateCount
        self.dataUpdatedAt = dataUpdatedAt ?? (data != nil ? Int64(Date().timeIntervalSince1970 * 1000) : 0)
        self.error = error
        self.errorUpdateCount = errorUpdateCount
        self.errorUpdatedAt = errorUpdatedAt
        self.fetchFailureCount = fetchFailureCount
        self.fetchFailureReason = fetchFailureReason
        self.fetchMeta = fetchMeta
        self.isInvalidated = isInvalidated
        self.status = status ?? (data != nil ? .success : .pending)
        self.fetchStatus = fetchStatus
    }

    /// Create default empty state
    public static func defaultState() -> QueryState<TData, TError> {
        QueryState<TData, TError>()
    }

    /// Create a copy with updated data
    public func withData(_ newData: TData?) -> QueryState<TData, TError> {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return Self(
            data: newData,
            dataUpdateCount: newData != nil ? dataUpdateCount + 1 : dataUpdateCount,
            dataUpdatedAt: newData != nil ? now : dataUpdatedAt,
            error: newData != nil ? nil : error, // Clear error on successful data
            errorUpdateCount: errorUpdateCount,
            errorUpdatedAt: errorUpdatedAt,
            fetchFailureCount: newData != nil ? 0 : fetchFailureCount, // Reset failure count on success
            fetchFailureReason: newData != nil ? nil : fetchFailureReason,
            fetchMeta: fetchMeta,
            isInvalidated: isInvalidated,
            status: newData != nil ? .success : status,
            fetchStatus: fetchStatus
        )
    }

    /// Create a copy with updated error
    public func withError(_ newError: TError?) -> QueryState<TData, TError> {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return Self(
            data: data,
            dataUpdateCount: dataUpdateCount,
            dataUpdatedAt: dataUpdatedAt,
            error: newError,
            errorUpdateCount: newError != nil ? errorUpdateCount + 1 : errorUpdateCount,
            errorUpdatedAt: newError != nil ? now : errorUpdatedAt,
            fetchFailureCount: newError != nil ? fetchFailureCount + 1 : fetchFailureCount,
            fetchFailureReason: newError,
            fetchMeta: fetchMeta,
            isInvalidated: isInvalidated,
            status: newError != nil ? .error : status,
            fetchStatus: fetchStatus
        )
    }

    /// Create a copy with updated fetch status
    public func withFetchStatus(_ newFetchStatus: FetchStatus) -> QueryState<TData, TError> {
        Self(
            data: data,
            dataUpdateCount: dataUpdateCount,
            dataUpdatedAt: dataUpdatedAt,
            error: error,
            errorUpdateCount: errorUpdateCount,
            errorUpdatedAt: errorUpdatedAt,
            fetchFailureCount: fetchFailureCount,
            fetchFailureReason: fetchFailureReason,
            fetchMeta: fetchMeta,
            isInvalidated: isInvalidated,
            status: status,
            fetchStatus: newFetchStatus
        )
    }

    /// Create a copy with invalidated flag set
    public func invalidated() -> QueryState<TData, TError> {
        Self(
            data: data,
            dataUpdateCount: dataUpdateCount,
            dataUpdatedAt: dataUpdatedAt,
            error: error,
            errorUpdateCount: errorUpdateCount,
            errorUpdatedAt: errorUpdatedAt,
            fetchFailureCount: fetchFailureCount,
            fetchFailureReason: fetchFailureReason,
            fetchMeta: fetchMeta,
            isInvalidated: true,
            status: status,
            fetchStatus: fetchStatus
        )
    }

    // MARK: - Computed Convenience Properties

    /// Whether there is data available
    public var hasData: Bool { data != nil }

    /// Whether there is an error
    public var hasError: Bool { error != nil }

    /// Whether the query is currently fetching
    public var isFetching: Bool { fetchStatus == .fetching }

    /// Whether the query is paused
    public var isPaused: Bool { fetchStatus == .paused }

    /// Whether the query is idle (not fetching)
    public var isIdle: Bool { fetchStatus == .idle }

    /// Convert dataUpdatedAt to Date
    public var dataUpdatedDate: Date? {
        guard dataUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(dataUpdatedAt) / 1000.0)
    }

    /// Convert errorUpdatedAt to Date
    public var errorUpdatedDate: Date? {
        guard errorUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(errorUpdatedAt) / 1000.0)
    }
}

// MARK: - Query Error Types

/// Standard error type for query operations
public struct QueryError: Error, Sendable, Codable, Equatable {
    public let message: String
    public let code: String?
    public let underlyingError: String?

    public init(message: String, code: String? = nil, underlyingError: Error? = nil) {
        self.message = message
        self.code = code
        self.underlyingError = underlyingError?.localizedDescription
    }
}

/// Observer identifier for tracking query observers
public struct QueryObserverIdentifier: Sendable, Hashable, Codable {
    public let id: UUID

    public init() {
        self.id = UUID()
    }
}

// MARK: - Cache Infrastructure

/// Thread-safe mutex actor for coordinating cache operations
/// Provides synchronization for concurrent access to shared cache state
public actor Mutex {
    private var isLocked = false
    private var waitingTasks: [CheckedContinuation<Void, Never>] = []

    /// Acquire the mutex lock
    /// Suspends the calling task until the lock is available
    public func lock() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waitingTasks.append(continuation)
        }
    }

    /// Release the mutex lock
    /// Resumes the next waiting task if any
    public func unlock() {
        guard isLocked else { return }

        if let nextTask = waitingTasks.first {
            waitingTasks.removeFirst()
            nextTask.resume()
        } else {
            isLocked = false
        }
    }

    /// Execute a critical section with automatic lock/unlock
    /// Ensures the lock is always released even if the operation throws
    public func withLock<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await lock()
        defer {
            Task { await self.unlock() }
        }
        return try await operation()
    }

    /// Check if the mutex is currently locked (for testing purposes)
    public nonisolated var isCurrentlyLocked: Bool {
        get async {
            await isLocked
        }
    }
}

/// Event types for cache notifications
/// Equivalent to TanStack Query's cache event system
public enum QueryCacheEvent: Sendable {
    case added(queryHash: String)
    case removed(queryHash: String)
    case updated(queryHash: String)
    case cleared
}

/// Listener function type for cache events
public typealias QueryCacheListener = @Sendable (QueryCacheEvent) -> Void

/// Thread-safe cache for storing and managing query instances
/// Equivalent to TanStack Query's QueryCache with Observer pattern
/// Note: @MainActor is currently required because AnyQuery protocol is @MainActor
/// In a future refactor, we could make QueryCache truly thread-safe with an actor-based design
@MainActor
public final class QueryCache {
    /// Internal dictionary storing queries by their hash
    private var queries: [String: AnyQuery] = [:]

    /// Set of event listeners for cache notifications
    private var listeners: Set<QueryCacheListenerWrapper> = []

    /// Mutex for coordinating thread-safe operations
    private let mutex = Mutex()

    public init() {}

    // MARK: - Query Management

    /// Add a query to the cache
    /// Notifies listeners of the addition
    public func add(_ query: AnyQuery) {
        let queryHash = query.queryHash
        queries[queryHash] = query
        notify(.added(queryHash: queryHash))
    }

    /// Remove a query from the cache
    /// Notifies listeners of the removal
    public func remove(_ query: AnyQuery) {
        let queryHash = query.queryHash
        queries.removeValue(forKey: queryHash)
        notify(.removed(queryHash: queryHash))
    }

    /// Get a query by its hash
    public func get(queryHash: String) -> AnyQuery? {
        queries[queryHash]
    }

    /// Check if a query exists in the cache
    public func has(queryHash: String) -> Bool {
        queries[queryHash] != nil
    }

    /// Get all queries in the cache
    public var allQueries: [AnyQuery] {
        Array(queries.values)
    }

    /// Clear all queries from the cache
    /// Notifies listeners of the clear operation
    public func clear() {
        queries.removeAll()
        notify(.cleared)
    }

    /// Find queries matching the given predicate
    public func findAll(matching predicate: (AnyQuery) -> Bool) -> [AnyQuery] {
        queries.values.filter(predicate)
    }

    /// Find the first query matching the given predicate
    public func find(matching predicate: (AnyQuery) -> Bool) -> AnyQuery? {
        queries.values.first(where: predicate)
    }

    // MARK: - Observer Pattern

    /// Subscribe to cache events
    /// Returns a function to unsubscribe
    public func subscribe(_ listener: @escaping QueryCacheListener) -> () -> Void {
        let wrapper = QueryCacheListenerWrapper(listener: listener)
        listeners.insert(wrapper)

        return { [weak self] in
            self?.listeners.remove(wrapper)
        }
    }

    /// Notify all listeners of a cache event
    private func notify(_ event: QueryCacheEvent) {
        for listener in listeners {
            listener.listener(event)
        }
    }

    // MARK: - Thread-Safe Operations

    /// Execute an operation with thread-safe access to the cache
    public func withLock<T: Sendable>(_ operation: @MainActor @Sendable () async throws -> T) async rethrows -> T {
        try await mutex.withLock {
            try await operation()
        }
    }

    // MARK: - Cache Statistics

    /// Get the number of queries in the cache
    public var count: Int {
        queries.count
    }

    /// Check if the cache is empty
    public var isEmpty: Bool {
        queries.isEmpty
    }

    /// Get all query hashes currently in the cache
    public var queryHashes: Set<String> {
        Set(queries.keys)
    }
}

/// Type-erased query wrapper for storing different query types in the same cache
@MainActor
public protocol AnyQuery {
    var queryHash: String { get }
    var isStale: Bool { get }
    var lastUpdated: Date? { get }
}

/// Wrapper for query cache listeners to make them Hashable for Set storage
private struct QueryCacheListenerWrapper: Hashable {
    let id = UUID()
    let listener: QueryCacheListener

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
