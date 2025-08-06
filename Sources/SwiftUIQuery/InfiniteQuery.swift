// InfiniteQuery.swift - Individual infinite query instance with pagination support
// Based on TanStack Query's InfiniteQuery class and infinite query behavior

import Foundation
import Perception

// MARK: - Type-Erased Infinite Query Protocol

/// Protocol for type-erased infinite queries
@MainActor
public protocol AnyInfiniteQuery: Sendable {
    func hasNextPage() -> Bool
    func hasPreviousPage() -> Bool
    func isFetchingNextPage() -> Bool
    func isFetchingPreviousPage() -> Bool
    var fetchDirection: FetchDirection? { get }
}

// MARK: - Infinite Query Actions

/// Actions specific to infinite queries
/// Extends regular QueryAction with pagination-specific actions
public enum InfiniteQueryAction<TData: Sendable, TPageParam: Sendable & Codable> {
    case fetchPage(direction: FetchDirection, param: TPageParam?, meta: QueryMeta?)
    case addPage(page: TData, param: TPageParam?, direction: FetchDirection)
    case limitPages(maxPages: Int)
}

/// Direction for page fetching
public enum FetchDirection: Sendable {
    case forward // fetchNextPage
    case backward // fetchPreviousPage
}

// MARK: - Infinite Query Meta

/// Metadata for infinite query fetch operations
public struct InfiniteQueryFetchMeta: Sendable {
    public let direction: FetchDirection
    public let pageParam: String? // String representation of page parameter

    public init(direction: FetchDirection, pageParam: String? = nil) {
        self.direction = direction
        self.pageParam = pageParam
    }
}

// MARK: - Infinite Query Configuration

/// Configuration for creating an InfiniteQuery instance
/// Equivalent to TanStack Query's InfiniteQueryConfig
public struct InfiniteQueryConfig<
    TData: Sendable,
    TKey: QueryKey,
    TPageParam: Sendable & Codable & Equatable
> {
    public let queryKey: TKey
    public let queryHash: String
    public let options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>?
    public let defaultOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>?
    public let state: QueryState<InfiniteData<TData, TPageParam>>?

    public init(
        queryKey: TKey,
        queryHash: String,
        options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>? = nil,
        defaultOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>? = nil,
        state: QueryState<InfiniteData<TData, TPageParam>>? = nil
    ) {
        self.queryKey = queryKey
        self.queryHash = queryHash
        self.options = options
        self.defaultOptions = defaultOptions
        self.state = state
    }
}

// MARK: - Infinite Query Class

/// Individual infinite query instance that manages paginated data fetching
/// Extends the base Query functionality with pagination support
/// Equivalent to TanStack Query's InfiniteQuery class
@MainActor
public final class InfiniteQuery<
    TData: Sendable,
    TKey: QueryKey,
    TPageParam: Sendable & Codable & Equatable
>: AnyQuery, AnyInfiniteQuery {
    // MARK: - Public Properties

    /// The unique key identifying this query
    public let queryKey: TKey

    /// The hash string derived from the query key
    public let queryHash: String

    /// Current infinite query options (merged with defaults)
    public private(set) var options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>

    /// Current state of the infinite query
    public private(set) var state: QueryState<InfiniteData<TData, TPageParam>>

    /// List of observers watching this query
    public private(set) var observers: [AnyQueryObserver] = []

    // MARK: - Private Properties

    /// Initial state when query was created
    private let initialState: QueryState<InfiniteData<TData, TPageParam>>

    /// State to revert to if current fetch is cancelled
    private var revertState: QueryState<InfiniteData<TData, TPageParam>>?

    /// Default options provided during initialization
    private let defaultOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>?

    /// Reference to the query cache that owns this query
    private weak var cache: QueryCache?

    /// Current fetch task (if any)
    @PerceptionIgnored private nonisolated(unsafe) var fetchTask: Task<InfiniteData<TData, TPageParam>, Error>?

    /// Whether the query has been destroyed
    private var isDestroyed = false

    /// Timestamp when query became inactive (no active observers)
    private var inactiveAt: Date?

    /// Current fetch direction (if fetching)
    var currentFetchDirection: FetchDirection?

    // MARK: - Initialization

    public init(config: InfiniteQueryConfig<TData, TKey, TPageParam>, cache: QueryCache) {
        self.queryKey = config.queryKey
        self.queryHash = config.queryHash
        self.defaultOptions = config.defaultOptions
        self.cache = cache

        // Set options (merging defaults) first so we can use them for initial state
        self.options = Self.mergeOptions(config.options, config.defaultOptions)

        // Initialize with state that considers initial data
        self.initialState = config.state ?? Self.createInitialState(from: self.options)
        self.state = self.initialState
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
    public func isStaleByTime(staleTime: TimeInterval = 0) -> Bool {
        // No data is always stale
        guard let data = state.data, !data.isEmpty else { return true }

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
    public func setOptions(_ newOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>?) {
        self.options = Self.mergeOptions(newOptions, defaultOptions)
    }

    /// Create initial state from infinite query options
    private static func createInitialState(
        from options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>
    ) -> QueryState<InfiniteData<TData, TPageParam>> {
        // For infinite queries, we always start with empty data
        // Initial data would be handled by the first page fetch
        let emptyInfiniteData = InfiniteData<TData, TPageParam>()

        return QueryState<InfiniteData<TData, TPageParam>>(
            data: emptyInfiniteData,
            dataUpdateCount: 0,
            dataUpdatedAt: 0,
            error: nil,
            errorUpdateCount: 0,
            errorUpdatedAt: 0,
            fetchFailureCount: 0,
            fetchFailureReason: nil,
            fetchMeta: nil,
            isInvalidated: false,
            status: .pending,
            fetchStatus: .idle
        )
    }

    private static func mergeOptions(
        _ options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>?,
        _ defaultOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>?
    ) -> InfiniteQueryOptions<TData, QueryError, TKey, TPageParam> {
        // For now, return options or create a minimal default
        // In a full implementation, this would merge all option properties
        if let options {
            return options
        } else if let defaultOptions {
            return defaultOptions
        } else {
            // Create minimal default options
            fatalError("InfiniteQuery must have either options or defaultOptions")
        }
    }

    // MARK: - State Management

    /// Dispatch an action to update query state
    public func dispatch(_ action: QueryAction<InfiniteData<TData, TPageParam>>) {
        let newState = reducer(state: state, action: action)
        setState(newState)
    }

    /// Dispatch an infinite query specific action
    public func dispatchInfinite(_ action: InfiniteQueryAction<TData, TPageParam>) {
        let newState = infiniteReducer(state: state, action: action)
        setState(newState)
    }

    /// Update the query state and notify observers
    private func setState(_ newState: QueryState<InfiniteData<TData, TPageParam>>) {
        let oldState = state
        state = newState

        // Log state transitions for cache activity
        let dataChanged = (oldState.data?.pageCount ?? 0) != (newState.data?.pageCount ?? 0) ||
            oldState.dataUpdateCount != newState.dataUpdateCount
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

    /// State reducer for regular query actions
    private func reducer(
        state: QueryState<InfiniteData<TData, TPageParam>>,
        action: QueryAction<InfiniteData<TData, TPageParam>>
    ) -> QueryState<InfiniteData<TData, TPageParam>> {
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
                error: data != nil ? nil : state.error,
                errorUpdateCount: state.errorUpdateCount,
                errorUpdatedAt: state.errorUpdatedAt,
                fetchFailureCount: data != nil ? 0 : state.fetchFailureCount,
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

    /// State reducer for infinite query specific actions
    private func infiniteReducer(
        state: QueryState<InfiniteData<TData, TPageParam>>,
        action: InfiniteQueryAction<TData, TPageParam>
    ) -> QueryState<InfiniteData<TData, TPageParam>> {
        switch action {
        case let .fetchPage(direction, param, _):
            // Set current fetch direction
            currentFetchDirection = direction

            // Create fetch meta with direction information
            let infiniteMeta: QueryMeta = [
                "direction": AnyCodable(direction == .forward ? "forward" : "backward"),
                "pageParam": AnyCodable(param.map(String.init(describing:)) ?? "nil")
            ]

            return state
                .withFetchStatus(.fetching)
                .withFetchMeta(infiniteMeta)

        case let .addPage(page, param, direction):
            guard let currentData = state.data else {
                // Create new infinite data with first page
                let newData = InfiniteData(pages: [page], pageParams: [param])
                return state.withData(newData)
            }

            // Add page in the appropriate direction
            let newData = direction == .forward
                ? currentData.appendPage(page, param: param)
                : currentData.prependPage(page, param: param)

            return state.withData(newData)

        case let .limitPages(maxPages):
            guard let currentData = state.data else { return state }

            let limitedData = currentData.limitPages(to: maxPages)
            return state.withData(limitedData)
        }
    }

    /// Apply partial state update to current state
    private func applyPartialState(
        current: QueryState<InfiniteData<TData, TPageParam>>,
        partial: PartialQueryState<InfiniteData<TData, TPageParam>>
    ) -> QueryState<InfiniteData<TData, TPageParam>> {
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

    // MARK: - Infinite Query Operations

    /// Set infinite data directly (for imperative updates)
    @discardableResult
    public func setData(_ newData: InfiniteData<TData, TPageParam>) -> InfiniteData<TData, TPageParam> {
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
    public func cancel() {
        fetchTask?.cancel()
        fetchTask = nil
        currentFetchDirection = nil

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

    // MARK: - Pagination Operations

    /// Get the next page parameter from current data
    public func getNextPageParam() -> TPageParam? {
        guard let data = state.data,
              !data.pages.isEmpty,
              let getNextPageParam = options.getNextPageParam else {
            return nil
        }

        return getNextPageParam(data.pages)
    }

    /// Get the previous page parameter from current data
    public func getPreviousPageParam() -> TPageParam? {
        guard let data = state.data,
              !data.pages.isEmpty,
              let getPreviousPageParam = options.getPreviousPageParam else {
            return nil
        }

        return getPreviousPageParam(data.pages)
    }

    /// Check if there are more pages available in the forward direction
    public func hasNextPage() -> Bool {
        getNextPageParam() != nil
    }

    /// Check if there are more pages available in the backward direction
    public func hasPreviousPage() -> Bool {
        getPreviousPageParam() != nil
    }

    /// Check if currently fetching next page
    public func isFetchingNextPage() -> Bool {
        state.fetchStatus == .fetching && currentFetchDirection == .forward
    }

    /// Check if currently fetching previous page
    public func isFetchingPreviousPage() -> Bool {
        state.fetchStatus == .fetching && currentFetchDirection == .backward
    }

    // MARK: - Fetch Implementation

    /// Fetch the next page
    public func fetchNextPage() async throws -> InfiniteData<TData, TPageParam> {
        guard let pageParam = getNextPageParam() else {
            throw QueryError.invalidConfiguration("No next page available")
        }

        return try await fetchPage(param: pageParam, direction: .forward)
    }

    /// Fetch the previous page
    public func fetchPreviousPage() async throws -> InfiniteData<TData, TPageParam> {
        guard let pageParam = getPreviousPageParam() else {
            throw QueryError.invalidConfiguration("No previous page available")
        }

        return try await fetchPage(param: pageParam, direction: .backward)
    }

    /// Internal fetch implementation for a specific page
    private func fetchPage(
        param: TPageParam?,
        direction: FetchDirection
    ) async throws -> InfiniteData<TData, TPageParam> {
        // Cancel any existing fetch
        fetchTask?.cancel()

        // Update state to fetching with direction
        dispatchInfinite(.fetchPage(direction: direction, param: param, meta: nil))

        // Create new fetch task
        let task = Task<InfiniteData<TData, TPageParam>, Error> { @MainActor in
            do {
                // Execute the query function with page parameter
                let pageData = try await options.queryFn(queryKey, param)

                // Check if task was cancelled
                if Task.isCancelled {
                    throw QueryError.cancelled
                }

                // Add the new page to existing data
                dispatchInfinite(.addPage(page: pageData, param: param, direction: direction))

                // Apply max pages limit if configured
                if let maxPages = options.maxPages {
                    dispatchInfinite(.limitPages(maxPages: maxPages))
                }

                // Update state with success
                guard let updatedData = state.data else {
                    throw QueryError.invalidConfiguration("Data should exist after adding page")
                }

                dispatch(.success(data: updatedData, dataUpdatedAt: nil, manual: false))

                // Clear the fetch task and direction
                self.fetchTask = nil
                self.currentFetchDirection = nil

                return updatedData
            } catch {
                // Check if task was cancelled
                if Task.isCancelled {
                    throw QueryError.cancelled
                }

                // Convert error to QueryError
                let typedError: QueryError = if let queryError = error as? QueryError {
                    queryError
                } else {
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
                    return try await fetchPage(param: param, direction: direction)
                } else {
                    // Max retries reached or should not retry
                    self.fetchTask = nil
                    self.currentFetchDirection = nil
                    throw typedError
                }
            }
        }

        // Store the task
        fetchTask = task

        // Wait for the task to complete
        return try await task.value
    }

    /// Initial fetch for the first page
    /// This preserves existing data during refetch to avoid empty page (TanStack Query behavior)
    public func internalFetch() async throws -> InfiniteData<TData, TPageParam> {
        // Store current state to revert if fetch is cancelled
        revertState = state

        // Cancel any existing fetch
        fetchTask?.cancel()

        // Update fetch status to indicate we're fetching
        // This preserves existing data while showing fetching state
        dispatch(.fetch(meta: nil))

        let initialParam = options.initialPageParam

        // Create new fetch task
        let task = Task<InfiniteData<TData, TPageParam>, Error> { @MainActor in
            do {
                // Execute the query function with initial page parameter
                let pageData = try await options.queryFn(queryKey, initialParam)

                // Check if task was cancelled
                if Task.isCancelled {
                    throw QueryError.cancelled
                }

                // Create new infinite data with the first page
                let newData = InfiniteData(pages: [pageData], pageParams: [initialParam])

                // Update state with the new data (replacing old data)
                dispatch(.success(data: newData, dataUpdatedAt: nil, manual: false))

                // Clear the fetch task and direction
                self.fetchTask = nil
                self.currentFetchDirection = nil

                return newData
            } catch {
                // Handle error cases
                if Task.isCancelled {
                    throw QueryError.cancelled
                }

                let typedError: QueryError = if let queryError = error as? QueryError {
                    queryError
                } else {
                    classifyError(error)
                }

                dispatch(.error(error: typedError))

                self.fetchTask = nil
                self.currentFetchDirection = nil
                throw typedError
            }
        }

        // Store the task
        fetchTask = task

        // Wait for the task to complete
        return try await task.value
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
            // Cancel ongoing fetch if no observers and allow revert
            if let revertState {
                setState(revertState)
                self.revertState = nil
            }

            // If the query is still fetching, let it continue to cache the result
            // Only cancel if we can safely revert
            if fetchTask != nil, revertState != nil {
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
        from oldState: QueryState<InfiniteData<TData, TPageParam>>,
        to newState: QueryState<InfiniteData<TData, TPageParam>>
    ) {
        // If fetch finishes and query is inactive, mark timestamp
        if oldState.fetchStatus == .fetching, newState.fetchStatus == .idle {
            if observers.isEmpty {
                inactiveAt = Date()
            }
        }
    }

    /// Optionally remove query from cache if conditions are met
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
        currentFetchDirection = nil
    }
}

// MARK: - AnyInfiniteQuery Protocol Implementation

extension InfiniteQuery {
    /// Current fetch direction (exposed for result computation)
    public var fetchDirection: FetchDirection? {
        currentFetchDirection
    }
}
