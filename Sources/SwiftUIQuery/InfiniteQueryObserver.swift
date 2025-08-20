// InfiniteQueryObserver.swift - Reactive observer for infinite query state changes
// Based on TanStack Query's InfiniteQueryObserver class

import Foundation
import Perception

// MARK: - Infinite Query Observer Result

/// Result object containing all infinite query state and computed properties
/// Equivalent to TanStack Query's InfiniteQueryObserverResult
public struct InfiniteQueryObserverResult<TData: Sendable, TPageParam: Sendable & Codable>: Sendable {
    /// The underlying query state
    private let queryState: QueryState<InfiniteData<TData, TPageParam>>
    /// Whether the query is stale (computed from observer context)
    private let _isStale: Bool
    /// Computed pagination states
    private let _hasNextPage: Bool
    private let _hasPreviousPage: Bool
    private let _isFetchingNextPage: Bool
    private let _isFetchingPreviousPage: Bool
    private let _isFetchNextPageError: Bool
    private let _isFetchPreviousPageError: Bool

    init(
        queryState: QueryState<InfiniteData<TData, TPageParam>>,
        isStale: Bool,
        hasNextPage: Bool = false,
        hasPreviousPage: Bool = false,
        isFetchingNextPage: Bool = false,
        isFetchingPreviousPage: Bool = false,
        isFetchNextPageError: Bool = false,
        isFetchPreviousPageError: Bool = false
    ) {
        self.queryState = queryState
        self._isStale = isStale
        self._hasNextPage = hasNextPage
        self._hasPreviousPage = hasPreviousPage
        self._isFetchingNextPage = isFetchingNextPage
        self._isFetchingPreviousPage = isFetchingPreviousPage
        self._isFetchNextPageError = isFetchNextPageError
        self._isFetchPreviousPageError = isFetchPreviousPageError
    }

    // MARK: - Data Properties (direct from QueryState)

    /// The infinite data containing all pages
    public var data: InfiniteData<TData, TPageParam>? { queryState.data }

    /// The error if the query failed
    public var error: QueryError? { queryState.error }

    /// Number of times the query has been fetched
    public var dataUpdateCount: Int { queryState.dataUpdateCount }

    /// Number of times the query has failed
    public var errorUpdateCount: Int { queryState.errorUpdateCount }

    /// Number of consecutive failures
    public var failureCount: Int { queryState.fetchFailureCount }

    /// Reason for the last failure
    public var failureReason: QueryError? { queryState.fetchFailureReason }

    /// Timestamp when data was last updated
    public var dataUpdatedAt: Date? {
        guard queryState.dataUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(queryState.dataUpdatedAt) / 1000.0)
    }

    /// Timestamp when error was last updated
    public var errorUpdatedAt: Date? {
        guard queryState.errorUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(queryState.errorUpdatedAt) / 1000.0)
    }

    // MARK: - Computed Status Properties

    /// Whether the query is currently fetching (including background refetch)
    public var isFetching: Bool { queryState.fetchStatus == .fetching }

    /// Whether the query is paused due to being offline
    public var isPaused: Bool { queryState.fetchStatus == .paused }

    /// Whether the query is in pending state (no data yet)
    public var isPending: Bool { queryState.status == .pending }

    /// Whether the query is successful and has data
    public var isSuccess: Bool { queryState.status == .success }

    /// Whether the query failed with an error
    public var isError: Bool { queryState.status == .error }

    /// Whether the query is currently loading for the first time
    public var isLoading: Bool { isPending && isFetching }

    /// Whether the query is currently refetching in the background
    public var isRefetching: Bool { isFetching && !isPending }

    /// Whether the query data is stale
    public var isStale: Bool { _isStale }

    // MARK: - Infinite Query Specific Properties

    /// Whether there are more pages available in the forward direction
    public var hasNextPage: Bool { _hasNextPage }

    /// Whether there are more pages available in the backward direction
    public var hasPreviousPage: Bool { _hasPreviousPage }

    /// Whether currently fetching the next page
    public var isFetchingNextPage: Bool { _isFetchingNextPage }

    /// Whether currently fetching the previous page
    public var isFetchingPreviousPage: Bool { _isFetchingPreviousPage }

    /// Whether the last fetchNextPage call resulted in an error
    public var isFetchNextPageError: Bool { _isFetchNextPageError }

    /// Whether the last fetchPreviousPage call resulted in an error
    public var isFetchPreviousPageError: Bool { _isFetchPreviousPageError }
}

// MARK: - Infinite Query Observer Class

/// Reactive observer that manages infinite query subscriptions and provides SwiftUI-compatible state
/// Equivalent to TanStack Query's InfiniteQueryObserver
/// This is the bridge between the core InfiniteQuery class and SwiftUI reactive updates
@MainActor
@Perceptible
public final class InfiniteQueryObserver<
    TData: Sendable,
    TKey: QueryKey,
    TPageParam: Sendable & Codable & Equatable
>: AnyQueryObserver, ObservableObject {
    // MARK: - Public Properties

    /// Unique identifier for this observer
    public let id = QueryObserverIdentifier()

    /// Current result containing all infinite query state
    public private(set) var result: InfiniteQueryObserverResult<TData, TPageParam>

    /// Current infinite query options
    @PerceptionIgnored public private(set) var options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>

    // MARK: - Convenience Properties (derived from result)

    /// The infinite data containing all pages
    public var data: InfiniteData<TData, TPageParam>? { result.data }

    /// The error if the query failed
    public var error: QueryError? { result.error }

    /// Whether the query is currently loading for the first time
    public var isLoading: Bool { result.isLoading }

    /// Whether the query is currently fetching (including background refetch)
    public var isFetching: Bool { result.isFetching }

    /// Whether the query is successful and has data
    public var isSuccess: Bool { result.isSuccess }

    /// Whether the query failed with an error
    public var isError: Bool { result.isError }

    /// Whether the query is in pending state (no data yet)
    public var isPending: Bool { result.isPending }

    /// Whether the query is currently refetching in the background
    public var isRefetching: Bool { result.isRefetching }

    /// Whether the query data is stale
    public var isStale: Bool { result.isStale }

    /// Whether the query is paused due to being offline
    public var isPaused: Bool { result.isPaused }

    /// Whether there are more pages available in the forward direction
    public var hasNextPage: Bool { result.hasNextPage }

    /// Whether there are more pages available in the backward direction
    public var hasPreviousPage: Bool { result.hasPreviousPage }

    /// Whether currently fetching the next page
    public var isFetchingNextPage: Bool { result.isFetchingNextPage }

    /// Whether currently fetching the previous page
    public var isFetchingPreviousPage: Bool { result.isFetchingPreviousPage }

    /// Whether the last fetchNextPage call resulted in an error
    public var isFetchNextPageError: Bool { result.isFetchNextPageError }

    /// Whether the last fetchPreviousPage call resulted in an error
    public var isFetchPreviousPageError: Bool { result.isFetchPreviousPageError }

    // MARK: - Private Properties

    /// Reference to the query client
    public let client: QueryClient

    /// Current infinite query instance
    private var currentQuery: InfiniteQuery<TData, TKey, TPageParam>?

    /// Whether the observer is currently subscribed
    public private(set) var isSubscribed = false

    /// Timer for stale timeout
    @PerceptionIgnored private nonisolated(unsafe) var staleTimer: Timer?

    /// Timer for refetch interval
    @PerceptionIgnored private nonisolated(unsafe) var refetchTimer: Timer?

    // MARK: - Initialization

    public init(client: QueryClient, options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>) {
        self.client = client
        self.options = options
        // Initialize with empty state
        self.result = InfiniteQueryObserverResult<TData, TPageParam>(
            queryState: QueryState<InfiniteData<TData, TPageParam>>(
                data: InfiniteData<TData, TPageParam>(),
                status: .pending
            ),
            isStale: true
        )

        // Initialize with query from client
        updateQuery()
    }

    deinit {
        // Clean up timers synchronously
        staleTimer?.invalidate()
        refetchTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Set new options for the observer
    /// This will update the underlying query and potentially trigger refetch
    public func setOptions(_ newOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>) {
        let previousOptions = options
        let previousQuery = currentQuery

        options = newOptions

        // Update or create new query if key changed
        updateQuery()

        // Update query options
        currentQuery?.setOptions(newOptions)

        // Determine if we should fetch based on option changes
        if isSubscribed {
            let shouldFetch = shouldFetchOnOptionsChange(
                previousQuery: previousQuery,
                previousOptions: previousOptions,
                newQuery: currentQuery,
                newOptions: newOptions
            )

            if shouldFetch {
                _ = executeFetch()
            }
        }

        // Update result
        updateResult()
    }

    /// Manually refetch the query (full refetch)
    @discardableResult
    public func refetch(cancelRefetch: Bool = true) -> Task<InfiniteData<TData, TPageParam>?, Error> {
        executeFetch(cancelRefetch: cancelRefetch)
    }

    /// Fetch the next page
    @discardableResult
    public func fetchNextPage() -> Task<InfiniteQueryObserverResult<TData, TPageParam>, Never> {
        Task { @MainActor in
            guard let query = currentQuery else { return result }

            do {
                _ = try await query.fetchNextPage()
            } catch {
                // Error will be reflected in the updated state
            }

            return result
        }
    }

    /// Fetch the previous page
    @discardableResult
    public func fetchPreviousPage() -> Task<InfiniteQueryObserverResult<TData, TPageParam>, Never> {
        Task { @MainActor in
            guard let query = currentQuery else { return result }

            do {
                _ = try await query.fetchPreviousPage()
            } catch {
                // Error will be reflected in the updated state
            }

            return result
        }
    }

    /// Subscribe to query updates
    /// This should be called when the observer becomes active (e.g., view appears)
    public func subscribe() {
        guard !isSubscribed else { return }
        isSubscribed = true

        // Add self as observer to the query
        currentQuery?.addObserver(self)

        // Determine if we should fetch on mount
        if shouldFetchOnMount() {
            _ = executeFetch()
        } else {
            updateResult()
        }

        // Set up timers
        updateTimers()
    }

    /// Unsubscribe from query updates
    /// This should be called when the observer becomes inactive (e.g., view disappears)
    public func unsubscribe() {
        guard isSubscribed else { return }
        isSubscribed = false

        // Remove self as observer from the query
        currentQuery?.removeObserver(self)

        // Clean up timers
        clearTimers()
    }

    /// Destroy the observer and clean up all resources
    public func destroy() {
        unsubscribe()
        clearTimers()
        currentQuery = nil
    }

    // MARK: - AnyQueryObserver Protocol

    public func getCurrentResult() -> AnyQueryResult {
        AnyQueryResultWrapper(isStale: result.isStale)
    }

    public func onQueryUpdate() {
        updateResult()
    }

    public func isEnabled() -> Bool {
        options.enabled
    }

    public func shouldFetchOnWindowFocus() -> Bool {
        guard let query = currentQuery else { return false }
        return shouldFetchOn(query: query, options: options, trigger: options.refetchTriggers.onAppForeground)
    }

    public func shouldFetchOnReconnect() -> Bool {
        guard let query = currentQuery else { return false }
        return shouldFetchOn(query: query, options: options, trigger: options.refetchTriggers.onNetworkReconnect)
    }

    public func refetch(cancelRefetch: Bool) {
        _ = executeFetch(cancelRefetch: cancelRefetch)
    }

    // MARK: - Private Methods

    /// Update or create the current query based on current options
    private func updateQuery() {
        let newQuery = client.buildInfiniteQuery(options: options)

        if currentQuery !== newQuery {
            QueryLogger.shared.logObserverSwitchQuery(hash: newQuery.queryHash)

            // Unsubscribe from old query
            if isSubscribed {
                currentQuery?.removeObserver(self)
            }

            // Switch to new query
            currentQuery = newQuery

            // Subscribe to new query if we were subscribed
            if isSubscribed {
                currentQuery?.addObserver(self)
            }
        } else {
            QueryLogger.shared.logObserverReuseQuery(hash: newQuery.queryHash)
        }
    }

    /// Update the result based on current query state
    private func updateResult() {
        guard let query = currentQuery else {
            result = InfiniteQueryObserverResult<TData, TPageParam>(
                queryState: QueryState<InfiniteData<TData, TPageParam>>(
                    data: InfiniteData<TData, TPageParam>(),
                    status: .pending
                ),
                isStale: true
            )
            return
        }

        let queryState = query.state
        // Calculate staleness based on timestamp comparison
        let isStale = isEnabled() ? query.isStaleByTime(staleTime: options.staleTime) : false

        QueryLogger.shared.logObserverReadState(hash: query.queryHash)

        // Create new result with computed pagination states
        result = InfiniteQueryObserverResult(
            queryState: queryState,
            isStale: isStale,
            hasNextPage: query.hasNextPage(),
            hasPreviousPage: query.hasPreviousPage(),
            isFetchingNextPage: query.isFetchingNextPage(),
            isFetchingPreviousPage: query.isFetchingPreviousPage(),
            isFetchNextPageError: queryState.status == .error && query.fetchDirection == .forward,
            isFetchPreviousPageError: queryState.status == .error && query.fetchDirection == .backward
        )
    }

    /// Execute a fetch operation (full refetch of all pages)
    @discardableResult
    private func executeFetch(cancelRefetch: Bool = false) -> Task<InfiniteData<TData, TPageParam>?, Error> {
        Task<InfiniteData<TData, TPageParam>?, Error> { @MainActor () -> InfiniteData<TData, TPageParam>? in
            guard let query = currentQuery else { return nil }

            // Update result to show fetching state
            updateResult()

            do {
                // Execute the infinite query fetch operation
                try await query.fetch()

                // Update result to reflect new state
                updateResult()

                // Update timers after successful fetch
                updateTimers()

                // Return the current data from the updated state
                return query.state.data
            } catch {
                // Update result to show error state
                updateResult()

                // Re-throw the error
                throw error
            }
        }
    }

    /// Determine if we should fetch when the observer first mounts
    private func shouldFetchOnMount() -> Bool {
        guard let query = currentQuery else { return false }
        guard isEnabled() else { return false }

        // Always fetch if no data
        if query.state.data?.isEmpty != false {
            return true
        }

        // Fetch based on refetchOnAppear setting
        switch options.refetchOnAppear {
        case .always:
            return true
        case .ifStale:
            return query.isStaleByTime(staleTime: options.staleTime)
        case .never:
            return false
        }
    }

    /// Determine if we should fetch when options change
    private func shouldFetchOnOptionsChange(
        previousQuery: InfiniteQuery<TData, TKey, TPageParam>?,
        previousOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>,
        newQuery: InfiniteQuery<TData, TKey, TPageParam>?,
        newOptions: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>
    ) -> Bool {
        // If query key changed, always fetch
        if previousQuery !== newQuery {
            return isEnabled()
        }

        // If enabled state changed to true, fetch
        if !previousOptions.enabled, newOptions.enabled {
            return true
        }

        // If query function changed, fetch
        return false // For now, assume query function doesn't change
    }

    /// Helper to determine if should fetch based on a trigger condition
    private func shouldFetchOn(
        query: InfiniteQuery<TData, TKey, TPageParam>,
        options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>,
        trigger: Bool
    ) -> Bool {
        guard isEnabled(), trigger else { return false }

        // Only refetch if query is stale
        return query.isStaleByTime(staleTime: options.staleTime)
    }

    /// Set up timers for stale timeout and refetch interval
    private func updateTimers() {
        // Clear existing timers first
        clearTimers()

        // Set up stale timer
        // NOTE: staleTime timeout is not yet implemented in SwiftUIQuery
        // This would mark data as stale after staleTime duration
        // Currently, staleness is calculated on-demand via isStaleByTime

        // Set up refetch interval
        // NOTE: refetchInterval is not yet implemented in SwiftUIQuery
        // This would require adding refetchInterval and refetchIntervalInBackground
        // to InfiniteQueryOptions and implementing periodic refetching
    }

    /// Clear all timers
    private func clearTimers() {
        staleTimer?.invalidate()
        staleTimer = nil
        refetchTimer?.invalidate()
        refetchTimer = nil
    }
}

// MARK: - InfiniteQuery Extension for Fetch

extension InfiniteQuery {
    /// Fetch method that delegates to the internal implementation
    func fetch() async throws {
        _ = try await internalFetch()
    }
}

// MARK: - Type-Erased Query Result

/// Type-erased wrapper for AnyQueryResult
private struct AnyQueryResultWrapper: AnyQueryResult {
    let isStale: Bool
}
