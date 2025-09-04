// Query.swift - Individual query instance with state management and lifecycle
// Based on TanStack Query's Query class

import Foundation
import Perception

// MARK: - Query Actions

/// Actions that can be performed on a query to modify its state
/// Equivalent to TanStack Query's Action types
public enum QueryAction<TData: Sendable> {
    case fetch(meta: QueryMeta?)
    case success(data: TData?, dataUpdatedAt: Int64?, manual: Bool?)
    case error(error: QueryError)
    case failed(failureCount: Int, error: QueryError)
    case pause
    case continueAction
    case invalidate
    case setState(state: PartialQueryState<TData>)
}

/// Partial state for updating specific query state properties
public struct PartialQueryState<TData: Sendable> {
    public let data: TData?
    public let error: QueryError?
    public let fetchStatus: FetchStatus?
    public let status: QueryStatus?
    public let isInvalidated: Bool?
    public let fetchFailureCount: Int?
    public let fetchFailureReason: QueryError?
    public let fetchMeta: QueryMeta?

    public init(
        data: TData? = nil,
        error: QueryError? = nil,
        fetchStatus: FetchStatus? = nil,
        status: QueryStatus? = nil,
        isInvalidated: Bool? = nil,
        fetchFailureCount: Int? = nil,
        fetchFailureReason: QueryError? = nil,
        fetchMeta: QueryMeta? = nil
    ) {
        self.data = data
        self.error = error
        self.fetchStatus = fetchStatus
        self.status = status
        self.isInvalidated = isInvalidated
        self.fetchFailureCount = fetchFailureCount
        self.fetchFailureReason = fetchFailureReason
        self.fetchMeta = fetchMeta
    }
}

// MARK: - Query Configuration

/// Configuration for creating a Query instance
/// Equivalent to TanStack Query's QueryConfig
public struct QueryConfig<TData: Sendable, TKey: QueryKey> {
    public let queryKey: TKey
    public let queryHash: String
    public let options: QueryOptions<TData, TKey>?
    public let defaultOptions: QueryOptions<TData, TKey>?
    public let state: QueryState<TData>?

    public init(
        queryKey: TKey,
        queryHash: String,
        options: QueryOptions<TData, TKey>? = nil,
        defaultOptions: QueryOptions<TData, TKey>? = nil,
        state: QueryState<TData>? = nil
    ) {
        self.queryKey = queryKey
        self.queryHash = queryHash
        self.options = options
        self.defaultOptions = defaultOptions
        self.state = state
    }
}

// MARK: - Query Class

/// Individual query instance that manages data fetching, caching, and state
/// Equivalent to TanStack Query's Query class
/// Conforms to AnyQuery for type-erased storage in QueryCache
@MainActor
public final class Query<TData: Sendable, TKey: QueryKey>: AnyQuery {
    // MARK: - Public Properties

    /// The unique key identifying this query
    public let queryKey: TKey

    /// The hash string derived from the query key
    public let queryHash: String

    /// Current query options (merged with defaults)
    public private(set) var options: QueryOptions<TData, TKey>

    /// Current state of the query
    public private(set) var state: QueryState<TData>

    /// List of observers watching this query
    public private(set) var observers: [AnyQueryObserver] = []

    // MARK: - Private Properties

    /// Initial state when query was created
    private let initialState: QueryState<TData>

    /// State to revert to if current fetch is cancelled
    private var revertState: QueryState<TData>?

    /// Default options provided during initialization
    private let defaultOptions: QueryOptions<TData, TKey>?

    /// Reference to the query cache that owns this query
    private weak var cache: QueryCache?

    /// Current fetch task (if any)
    @PerceptionIgnored private nonisolated(unsafe) var fetchTask: Task<TData, Error>?

    /// Whether the query has been destroyed
    private var isDestroyed = false

    /// Timestamp when query became inactive (no active observers)
    private var inactiveAt: Date?

    // MARK: - Initialization

    public init(config: QueryConfig<TData, TKey>, cache: QueryCache) {
        self.queryKey = config.queryKey
        self.queryHash = config.queryHash
        self.defaultOptions = config.defaultOptions
        self.cache = cache

        // Set options (merging defaults) first so we can use them for initial state
        self.options = Self.mergeOptions(config.options, config.defaultOptions)

        // Initialize with state that considers initial data
        self.initialState = config.state ?? Self.createInitialState(from: self.options)
        self.state = self.initialState

        // Don't schedule GC on init - only when query becomes inactive
    }

    deinit {
        // Just cancel and clear - don't call cleanup which may need MainActor
        fetchTask?.cancel()
    }

    // MARK: - AnyQuery Protocol

    public var isStale: Bool {
        // Check observers first for their stale calculations
        if !observers.isEmpty {
            return observers.contains { observer in
                observer.getCurrentResult().isStale
            }
        }

        // Fallback: no data or invalidated = stale
        return state.data == nil || state.isInvalidated
    }

    /// Check if query is stale based on time elapsed since last update
    /// Based on TanStack Query's isStaleByTime implementation
    public func isStaleByTime(staleTime: TimeInterval = 0) -> Bool {
        // No data is always stale
        guard state.data != nil else { return true }

        // If the query is invalidated, it is stale
        if state.isInvalidated { return true }

        // Static queries (staleTime < 0) are never stale
        if staleTime < 0 { return false }

        // Check if enough time has passed since last update
        let timeSinceUpdate = Date().timeIntervalSince1970 - (Double(state.dataUpdatedAt) / 1000.0)
        return timeSinceUpdate >= staleTime
    }

    public var lastUpdated: Date? {
        guard state.dataUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(state.dataUpdatedAt) / 1000.0)
    }

    public var isActive: Bool {
        !observers.isEmpty && observers.contains { observer in
            observer.isEnabled()
        }
    }

    public var gcTime: TimeInterval {
        options.gcTime
    }

    /// Check if query is eligible for garbage collection
    public var isEligibleForGC: Bool {
        guard let inactiveAt else { return false }

        let effectiveGcTime = options.gcTime > 0 ? options.gcTime : defaultGcTime
        let timeSinceInactive = Date().timeIntervalSince(inactiveAt)
        return timeSinceInactive >= effectiveGcTime
    }

    // MARK: - Options Management

    /// Update query options and reconfigure
    public func setOptions(_ newOptions: QueryOptions<TData, TKey>?) {
        self.options = Self.mergeOptions(newOptions, defaultOptions)
    }

    /// Create initial state from query options, handling initial data
    private static func createInitialState(from options: QueryOptions<TData, TKey>) -> QueryState<TData> {
        // Check for initial data (direct value or function)
        let initialData: TData? = if let directData = options.initialData {
            directData
        } else if let initialDataFunction = options.initialDataFunction {
            initialDataFunction()
        } else {
            nil
        }

        // Create state with initial data if present
        if let data = initialData {
            // Calculate timestamp for initial data based on staleTime
            // If staleTime is 0 (default), set timestamp in the past to make data immediately stale
            // If staleTime > 0, set timestamp so data becomes stale after staleTime duration
            // This matches TanStack Query's behavior where initial data staleness respects staleTime
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let staleTimeMs = Int64(options.staleTime * 1000) // Convert to milliseconds

            let initialDataTimestamp: Int64 = if staleTimeMs <= 0 {
                // With staleTime 0 or negative, make data immediately stale
                now - 1
            } else {
                // With positive staleTime, set timestamp so data becomes stale exactly after staleTime
                // Set it to (now - staleTime) so that (now - timestamp) == staleTime (i.e., just stale)
                now - staleTimeMs
            }

            return QueryState<TData>(
                data: data,
                dataUpdateCount: 0, // Initial data doesn't count as an update
                dataUpdatedAt: initialDataTimestamp,
                error: nil,
                errorUpdateCount: 0,
                errorUpdatedAt: 0,
                fetchFailureCount: 0,
                fetchFailureReason: nil,
                fetchMeta: nil,
                isInvalidated: false,
                status: .success, // Initial data means we start in success state
                fetchStatus: .idle
            )
        } else {
            // No initial data, use default state
            return QueryState<TData>.defaultState()
        }
    }

    private static func mergeOptions(
        _ options: QueryOptions<TData, TKey>?,
        _ defaultOptions: QueryOptions<TData, TKey>?
    ) -> QueryOptions<TData, TKey> {
        // For now, return options or create a minimal default
        // In a full implementation, this would merge all option properties
        if let options {
            return options
        } else if let defaultOptions {
            return defaultOptions
        } else {
            // Create minimal default options
            fatalError("Query must have either options or defaultOptions")
        }
    }

    // MARK: - State Management

    /// Dispatch an action to update query state
    public func dispatch(_ action: QueryAction<TData>) {
        let newState = reducer(state: state, action: action)
        setState(newState)
    }

    /// Update the query state and notify observers
    private func setState(_ newState: QueryState<TData>) {
        let oldState = state
        state = newState

        // Log state transitions for cache activity
        let dataChanged = (oldState.data == nil) != (newState.data == nil) || oldState.dataUpdateCount != newState
            .dataUpdateCount
        if dataChanged {
            QueryLogger.shared.logQueryStateDataChanged(hash: queryHash)
        } else if oldState.status != newState.status || oldState.fetchStatus != newState.fetchStatus {
            QueryLogger.shared.logQueryStateStatusChanged(hash: queryHash)
        }

        // Notify observers of state change
        notifyObservers()

        // Handle state transitions
        handleStateTransition(from: oldState, to: newState)
    }

    /// State reducer that handles actions and returns new state
    private func reducer(
        state: QueryState<TData>,
        action: QueryAction<TData>
    ) -> QueryState<TData> {
        switch action {
        case let .fetch(meta):
            return state
                .withFetchStatus(.fetching)
                .withFetchMeta(meta)

        case let .success(data, dataUpdatedAt, _):
            let timestamp = dataUpdatedAt ?? Int64(Date().timeIntervalSince1970 * 1000)
            return QueryState(
                data: data,
                dataUpdateCount: data != nil ? state.dataUpdateCount + 1 : state.dataUpdateCount,
                dataUpdatedAt: data != nil ? timestamp : state.dataUpdatedAt,
                error: data != nil ? nil : state.error, // Clear error on success
                errorUpdateCount: state.errorUpdateCount,
                errorUpdatedAt: state.errorUpdatedAt,
                fetchFailureCount: data != nil ? 0 : state.fetchFailureCount, // Reset on success
                fetchFailureReason: data != nil ? nil : state.fetchFailureReason,
                fetchMeta: state.fetchMeta,
                isInvalidated: state.isInvalidated,
                status: data != nil ? .success : state.status,
                fetchStatus: .idle
            )

        case let .error(error):
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            return QueryState(
                data: state.data,
                dataUpdateCount: state.dataUpdateCount,
                dataUpdatedAt: state.dataUpdatedAt,
                error: error,
                errorUpdateCount: state.errorUpdateCount + 1,
                errorUpdatedAt: timestamp,
                fetchFailureCount: state.fetchFailureCount + 1,
                fetchFailureReason: error,
                fetchMeta: state.fetchMeta,
                isInvalidated: state.isInvalidated,
                status: .error,
                fetchStatus: .idle
            )

        case let .failed(failureCount, error):
            return QueryState(
                data: state.data,
                dataUpdateCount: state.dataUpdateCount,
                dataUpdatedAt: state.dataUpdatedAt,
                error: state.error,
                errorUpdateCount: state.errorUpdateCount,
                errorUpdatedAt: state.errorUpdatedAt,
                fetchFailureCount: failureCount,
                fetchFailureReason: error,
                fetchMeta: state.fetchMeta,
                isInvalidated: state.isInvalidated,
                status: state.status,
                fetchStatus: .idle
            )

        case .pause:
            return state.withFetchStatus(.paused)

        case .continueAction:
            return state.withFetchStatus(.fetching)

        case .invalidate:
            return state.invalidated()

        case let .setState(partialState):
            return applyPartialState(current: state, partial: partialState)
        }
    }

    /// Apply partial state update to current state
    private func applyPartialState(
        current: QueryState<TData>,
        partial: PartialQueryState<TData>
    ) -> QueryState<TData> {
        QueryState(
            data: partial.data ?? current.data,
            dataUpdateCount: current.dataUpdateCount,
            dataUpdatedAt: current.dataUpdatedAt,
            error: partial.error ?? current.error,
            errorUpdateCount: current.errorUpdateCount,
            errorUpdatedAt: current.errorUpdatedAt,
            fetchFailureCount: partial.fetchFailureCount ?? current.fetchFailureCount,
            fetchFailureReason: partial.fetchFailureReason ?? current.fetchFailureReason,
            fetchMeta: partial.fetchMeta ?? current.fetchMeta,
            isInvalidated: partial.isInvalidated ?? current.isInvalidated,
            status: partial.status ?? current.status,
            fetchStatus: partial.fetchStatus ?? current.fetchStatus
        )
    }

    // MARK: - Query Operations

    /// Set data directly (for imperative updates)
    @discardableResult
    public func setData(_ newData: TData) -> TData {
        QueryLogger.shared.logQueryDataSet(hash: queryHash)
        dispatch(.success(data: newData, dataUpdatedAt: nil, manual: true))
        return newData
    }

    /// Invalidate the query (mark as stale)
    public func invalidate() {
        if !state.isInvalidated {
            QueryLogger.shared.logQueryInvalidation(hash: queryHash)
            dispatch(.invalidate)
        }
    }

    /// Reset query to initial state
    public func reset() {
        QueryLogger.shared.logQueryReset(hash: queryHash)
        cancel()
        setState(initialState)
    }

    /// Cancel any ongoing fetch operation
    /// Note: This should only be called when explicitly requested or when no observers remain
    public func cancel() {
        fetchTask?.cancel()
        fetchTask = nil

        if state.fetchStatus == .fetching {
            dispatch(.setState(state: PartialQueryState(fetchStatus: .idle)))
        }
    }

    /// Destroy the query and clean up resources
    public func destroy() {
        guard !isDestroyed else { return }
        isDestroyed = true

        cancel()
        cleanup()

        // Remove from cache
        cache?.remove(self)
    }

    // MARK: - Observer Management

    /// Add an observer to this query
    public func addObserver(_ observer: AnyQueryObserver) {
        if !observers.contains(where: { $0.id == observer.id }) {
            observers.append(observer)

            // Clear inactive timestamp when query becomes active again
            inactiveAt = nil
        }
    }

    /// Remove an observer from this query
    public func removeObserver(_ observer: AnyQueryObserver) {
        observers.removeAll { $0.id == observer.id }

        if observers.isEmpty {
            // If there's a revert state and we're currently fetching, revert to previous state
            if let revertState, state.fetchStatus == .fetching {
                setState(revertState)
                self.revertState = nil
            }

            // Cancel any ongoing fetch when no observers remain
            // This prevents unnecessary network usage when no one is listening for the result
            if fetchTask != nil {
                fetchTask?.cancel()
                fetchTask = nil
            }

            // Mark query as inactive with timestamp
            inactiveAt = Date()
        }
    }

    /// Get the number of active observers
    public var observerCount: Int {
        observers.count
    }

    /// Check if query is disabled
    public func isDisabled() -> Bool {
        if observerCount > 0 {
            return !isActive
        }

        // No observers and never fetched = disabled
        return state.dataUpdateCount + state.errorUpdateCount == 0
    }

    // MARK: - Lifecycle Events

    /// Handle app focus event
    public func onFocus() {
        // Find observer that should refetch on focus
        if let observer = observers.first(where: { $0.shouldFetchOnWindowFocus() }) {
            observer.refetch(cancelRefetch: false)
        }

        // Continue any paused fetch
        if state.fetchStatus == .paused {
            dispatch(.continueAction)
        }
    }

    /// Handle network reconnect event
    public func onOnline() {
        // Find observer that should refetch on reconnect
        if let observer = observers.first(where: { $0.shouldFetchOnReconnect() }) {
            observer.refetch(cancelRefetch: false)
        }

        // Continue any paused fetch
        if state.fetchStatus == .paused {
            dispatch(.continueAction)
        }
    }

    // MARK: - Fetch Implementation

    /// Internal fetch implementation that executes the query function
    /// Implements request deduplication - if a fetch is already in progress,
    /// returns the existing promise instead of starting a new one
    public func internalFetch() async throws -> TData {
        // If we're already fetching, return the existing promise
        // This implements request deduplication similar to TanStack Query
        if let existingTask = fetchTask, state.fetchStatus == .fetching {
            // Return the existing task's value - all callers share the same request
            return try await existingTask.value
        }

        // Store current state to revert if fetch is cancelled
        revertState = state

        // Update state to fetching
        dispatch(.fetch(meta: nil))

        // Create new fetch task
        let task = Task<TData, Error> { @MainActor in
            do {
                // Execute the query function
                let data = try await options.queryFn(queryKey)

                // Check if task was cancelled
                if Task.isCancelled {
                    throw QueryError.cancelled
                }

                // Update state with success
                dispatch(.success(data: data, dataUpdatedAt: nil, manual: false))

                // Clear revertState on successful fetch (no longer needed)
                self.revertState = nil

                // Clear the fetch task
                self.fetchTask = nil

                return data
            } catch {
                // Check if task was cancelled
                if Task.isCancelled {
                    throw QueryError.cancelled
                }

                // Convert error to QueryError with proper classification
                let typedError: QueryError = if let queryError = error as? QueryError {
                    queryError
                } else {
                    // Classify error based on its type
                    classifyError(error)
                }

                // Update state with error
                dispatch(.error(error: typedError))

                // Handle retry logic
                let retryCount = state.fetchFailureCount
                if options.retryConfig.shouldRetry(failureCount: retryCount, error: typedError) {
                    // Calculate retry delay
                    let delay = options.retryConfig.delayForAttempt(failureCount: retryCount, error: typedError)

                    // Wait for retry delay
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Check if cancelled during sleep
                    if Task.isCancelled {
                        throw QueryError.cancelled
                    }

                    // Update failure count and retry
                    dispatch(.failed(failureCount: retryCount + 1, error: typedError))
                    return try await internalFetch()
                } else {
                    // Max retries reached or should not retry
                    self.fetchTask = nil
                    throw typedError
                }
            }
        }

        // Store the task
        fetchTask = task

        // Wait for the task to complete
        return try await task.value
    }

    // MARK: - Private Helpers

    /// Classify errors into appropriate QueryError types
    private func classifyError(_ error: Error) -> QueryError {
        // Handle URLError (network-related errors)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return QueryError.networkError(urlError)
            case .timedOut:
                return QueryError.timeout
            case .cancelled:
                return QueryError.cancelled
            default:
                return QueryError.networkError(urlError)
            }
        }

        // Handle DecodingError (JSON parsing errors)
        if error is DecodingError {
            return QueryError.decodingError(error)
        }

        // Handle NSError with HTTP status codes
        if let nsError = error as NSError?,
           nsError.domain == NSURLErrorDomain || nsError.domain == "NSURLErrorDomain" {
            return QueryError.networkError(error)
        }

        // Check if error has HTTP status code information
        // This covers URLSession errors that include HTTP response info
        if let httpError = extractHTTPError(from: error) {
            return httpError
        }

        // Default: treat as generic query failure
        return QueryError.queryFailed(error)
    }

    /// Extract HTTP error information from various error types
    private func extractHTTPError(from error: Error) -> QueryError? {
        // Check if error description contains HTTP status information
        let errorDescription = error.localizedDescription.lowercased()

        // Look for common HTTP status patterns
        if errorDescription.contains("404") || errorDescription.contains("not found") {
            return QueryError.notFound("Resource not found")
        }

        if errorDescription.contains("400") {
            return QueryError.clientError(statusCode: 400, message: "Bad Request")
        }

        if errorDescription.contains("401") {
            return QueryError.clientError(statusCode: 401, message: "Unauthorized")
        }

        if errorDescription.contains("403") {
            return QueryError.clientError(statusCode: 403, message: "Forbidden")
        }

        if errorDescription.contains("500") {
            return QueryError.serverError(statusCode: 500, message: "Internal Server Error")
        }

        if errorDescription.contains("502") {
            return QueryError.serverError(statusCode: 502, message: "Bad Gateway")
        }

        if errorDescription.contains("503") {
            return QueryError.serverError(statusCode: 503, message: "Service Unavailable")
        }

        // Check for general 4xx/5xx patterns
        if errorDescription.contains("4"), errorDescription.contains("client") {
            return QueryError.clientError(statusCode: 400, message: "Client Error")
        }

        if errorDescription.contains("5"), errorDescription.contains("server") {
            return QueryError.serverError(statusCode: 500, message: "Server Error")
        }

        return nil
    }

    /// Notify all observers of state changes
    private func notifyObservers() {
        for observer in observers {
            observer.onQueryUpdate()
        }
    }

    /// Handle state transitions and side effects
    private func handleStateTransition(
        from oldState: QueryState<TData>,
        to newState: QueryState<TData>
    ) {
        // If fetch finishes and query is inactive, mark timestamp
        if oldState.fetchStatus == .fetching, newState.fetchStatus == .idle {
            if observers.isEmpty {
                inactiveAt = Date()
            }
        }
    }

    /// Optionally remove query from cache if conditions are met
    /// Matches React Query's optionalRemove logic
    public func optionalRemove() {
        // Only remove if query has no observers and is eligible for GC
        guard observers.isEmpty, state.fetchStatus == .idle, isEligibleForGC else {
            #if DEBUG
                print("🗑️ SwiftUI Query: GC cancelled for \(queryHash) - Query is active or not eligible")
            #endif
            return
        }

        #if DEBUG
            print("🗑️ SwiftUI Query: Executing GC for \(queryHash)")
        #endif

        // Remove from cache (let cache handle the cleanup)
        cache?.remove(self)
    }

    /// Clean up resources
    private func cleanup() {
        fetchTask?.cancel()
        fetchTask = nil
        observers.removeAll()
        inactiveAt = nil
    }
}

// MARK: - QueryState Extensions

extension QueryState {
    /// Update state with new fetch meta
    func withFetchMeta(_ meta: QueryMeta?) -> QueryState<TData> {
        QueryState(
            data: data,
            dataUpdateCount: dataUpdateCount,
            dataUpdatedAt: dataUpdatedAt,
            error: error,
            errorUpdateCount: errorUpdateCount,
            errorUpdatedAt: errorUpdatedAt,
            fetchFailureCount: fetchFailureCount,
            fetchFailureReason: fetchFailureReason,
            fetchMeta: meta,
            isInvalidated: isInvalidated,
            status: status,
            fetchStatus: fetchStatus
        )
    }
}

// MARK: - Type-Erased Observer Protocol

/// Protocol for type-erased query observers
@MainActor
public protocol AnyQueryObserver {
    var id: QueryObserverIdentifier { get }

    func getCurrentResult() -> AnyQueryResult
    func onQueryUpdate()
    func isEnabled() -> Bool
    func shouldFetchOnWindowFocus() -> Bool
    func shouldFetchOnReconnect() -> Bool
    func refetch(cancelRefetch: Bool)
}

/// Type-erased query result
public protocol AnyQueryResult {
    var isStale: Bool { get }
}
