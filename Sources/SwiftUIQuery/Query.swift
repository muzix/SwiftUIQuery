// Query.swift - Individual query instance with state management and lifecycle
// Based on TanStack Query's Query class

import Foundation
import Perception

// MARK: - Query Actions

/// Actions that can be performed on a query to modify its state
/// Equivalent to TanStack Query's Action types
public enum QueryAction<TData: Sendable, TError: Error & Sendable & Codable> {
    case fetch(meta: QueryMeta?)
    case success(data: TData?, dataUpdatedAt: Int64?, manual: Bool?)
    case error(error: TError)
    case failed(failureCount: Int, error: TError)
    case pause
    case continueAction
    case invalidate
    case setState(state: PartialQueryState<TData, TError>)
}

/// Partial state for updating specific query state properties
public struct PartialQueryState<TData: Sendable, TError: Error & Sendable & Codable> {
    public let data: TData?
    public let error: TError?
    public let fetchStatus: FetchStatus?
    public let status: QueryStatus?
    public let isInvalidated: Bool?
    public let fetchFailureCount: Int?
    public let fetchFailureReason: TError?
    public let fetchMeta: QueryMeta?

    public init(
        data: TData? = nil,
        error: TError? = nil,
        fetchStatus: FetchStatus? = nil,
        status: QueryStatus? = nil,
        isInvalidated: Bool? = nil,
        fetchFailureCount: Int? = nil,
        fetchFailureReason: TError? = nil,
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
public struct QueryConfig<TData: Sendable, TError: Error & Sendable & Codable, TKey: QueryKey> {
    public let queryKey: TKey
    public let queryHash: String
    public let options: QueryOptions<TData, TError, TKey>?
    public let defaultOptions: QueryOptions<TData, TError, TKey>?
    public let state: QueryState<TData, TError>?

    public init(
        queryKey: TKey,
        queryHash: String,
        options: QueryOptions<TData, TError, TKey>? = nil,
        defaultOptions: QueryOptions<TData, TError, TKey>? = nil,
        state: QueryState<TData, TError>? = nil
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
@Perceptible
public final class Query<TData: Sendable, TError: Error & Sendable & Codable, TKey: QueryKey>: AnyQuery {
    // MARK: - Public Properties

    /// The unique key identifying this query
    public let queryKey: TKey

    /// The hash string derived from the query key
    public let queryHash: String

    /// Current query options (merged with defaults)
    public private(set) var options: QueryOptions<TData, TError, TKey>

    /// Current state of the query
    public private(set) var state: QueryState<TData, TError>

    /// List of observers watching this query
    public private(set) var observers: [AnyQueryObserver] = []

    // MARK: - Private Properties

    /// Initial state when query was created
    private let initialState: QueryState<TData, TError>

    /// State to revert to if current fetch is cancelled
    private var revertState: QueryState<TData, TError>?

    /// Default options provided during initialization
    private let defaultOptions: QueryOptions<TData, TError, TKey>?

    /// Reference to the query cache that owns this query
    private weak var cache: QueryCache?

    /// Current fetch task (if any)
    @PerceptionIgnored
    private nonisolated(unsafe) var fetchTask: Task<TData, Error>?

    /// Garbage collection timer for inactive queries
    @PerceptionIgnored
    private nonisolated(unsafe) var gcTimer: Timer?

    /// Whether the query has been destroyed
    private var isDestroyed = false

    // MARK: - Initialization

    public init(config: QueryConfig<TData, TError, TKey>, cache: QueryCache) {
        self.queryKey = config.queryKey
        self.queryHash = config.queryHash
        self.defaultOptions = config.defaultOptions
        self.cache = cache

        // Initialize with default state
        self.initialState = QueryState<TData, TError>.defaultState()
        self.state = config.state ?? self.initialState

        // Set options (merging defaults)
        self.options = Self.mergeOptions(config.options, config.defaultOptions)

        // Schedule garbage collection
        scheduleGarbageCollection()
    }

    deinit {
        // Just cancel and clear - don't call cleanup which may need MainActor
        fetchTask?.cancel()
        gcTimer?.invalidate()
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

    public var lastUpdated: Date? {
        guard state.dataUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(state.dataUpdatedAt) / 1000.0)
    }

    // MARK: - Options Management

    /// Update query options and reconfigure
    public func setOptions(_ newOptions: QueryOptions<TData, TError, TKey>?) {
        self.options = Self.mergeOptions(newOptions, defaultOptions)
        updateGarbageCollectionTime()
    }

    private static func mergeOptions(
        _ options: QueryOptions<TData, TError, TKey>?,
        _ defaultOptions: QueryOptions<TData, TError, TKey>?
    ) -> QueryOptions<TData, TError, TKey> {
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
    public func dispatch(_ action: QueryAction<TData, TError>) {
        let newState = reducer(state: state, action: action)
        setState(newState)
    }

    /// Update the query state and notify observers
    private func setState(_ newState: QueryState<TData, TError>) {
        let oldState = state
        state = newState

        // Notify observers of state change
        notifyObservers()

        // Handle state transitions
        handleStateTransition(from: oldState, to: newState)
    }

    /// State reducer that handles actions and returns new state
    private func reducer(
        state: QueryState<TData, TError>,
        action: QueryAction<TData, TError>
    ) -> QueryState<TData, TError> {
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
        current: QueryState<TData, TError>,
        partial: PartialQueryState<TData, TError>
    ) -> QueryState<TData, TError> {
        return QueryState(
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
        dispatch(.success(data: newData, dataUpdatedAt: nil, manual: true))
        return newData
    }

    /// Invalidate the query (mark as stale)
    public func invalidate() {
        if !state.isInvalidated {
            dispatch(.invalidate)
        }
    }

    /// Reset query to initial state
    public func reset() {
        cancel()
        setState(initialState)
    }

    /// Cancel any ongoing fetch operation
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
            clearGarbageCollectionTimer()

            // Notify cache of observer addition
            // cache?.notify(.observerAdded(queryHash: queryHash))
        }
    }

    /// Remove an observer from this query
    public func removeObserver(_ observer: AnyQueryObserver) {
        observers.removeAll { $0.id == observer.id }

        if observers.isEmpty {
            // Cancel fetch if no observers and allow revert
            if let revertState {
                setState(revertState)
                self.revertState = nil
            }

            scheduleGarbageCollection()
        }

        // Notify cache of observer removal
        // cache?.notify(.observerRemoved(queryHash: queryHash))
    }

    /// Get the number of active observers
    public var observerCount: Int {
        observers.count
    }

    /// Check if query is currently active (has enabled observers)
    public func isActive() -> Bool {
        return !observers.isEmpty && observers.contains { observer in
            observer.isEnabled()
        }
    }

    /// Check if query is disabled
    public func isDisabled() -> Bool {
        if observerCount > 0 {
            return !isActive()
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

    /// Notify all observers of state changes
    private func notifyObservers() {
        for observer in observers {
            observer.onQueryUpdate()
        }
    }

    /// Handle state transitions and side effects
    private func handleStateTransition(
        from oldState: QueryState<TData, TError>,
        to newState: QueryState<TData, TError>
    ) {
        // Handle any necessary side effects based on state changes
        // This could include triggering cache notifications, etc.
    }

    /// Schedule garbage collection for inactive queries
    private func scheduleGarbageCollection() {
        clearGarbageCollectionTimer()

        guard observers.isEmpty, state.fetchStatus == .idle else { return }

        let gcTime = options.gcTime
        guard gcTime > 0 else { return }

        gcTimer = Timer.scheduledTimer(withTimeInterval: gcTime, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performGarbageCollection()
            }
        }
    }

    /// Clear garbage collection timer
    private func clearGarbageCollectionTimer() {
        gcTimer?.invalidate()
        gcTimer = nil
    }

    /// Update garbage collection time when options change
    private func updateGarbageCollectionTime() {
        if observers.isEmpty, state.fetchStatus == .idle {
            scheduleGarbageCollection()
        }
    }

    /// Perform garbage collection (remove from cache)
    private func performGarbageCollection() {
        guard observers.isEmpty, state.fetchStatus == .idle else { return }
        destroy()
    }

    /// Clean up resources
    private func cleanup() {
        clearGarbageCollectionTimer()
        fetchTask?.cancel()
        fetchTask = nil
        observers.removeAll()
    }
}

// MARK: - QueryState Extensions

extension QueryState {
    /// Update state with new fetch meta
    func withFetchMeta(_ meta: QueryMeta?) -> QueryState<TData, TError> {
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
