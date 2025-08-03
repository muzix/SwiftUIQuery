// QueryObserver.swift - Reactive observer for query state changes
// Based on TanStack Query's QueryObserver class

import Foundation
import Perception

// MARK: - Query Observer Result

/// Result object containing all query state and methods
/// Equivalent to TanStack Query's QueryObserverResult
public struct QueryObserverResult<TData: Sendable> {
    /// The actual data returned by the query
    public let data: TData?
    /// The error if the query failed
    public let error: QueryError?
    /// Whether the query is currently loading for the first time
    public let isLoading: Bool
    /// Whether the query is currently fetching (including background refetch)
    public let isFetching: Bool
    /// Whether the query is successful and has data
    public let isSuccess: Bool
    /// Whether the query failed with an error
    public let isError: Bool
    /// Whether the query is in pending state (no data yet)
    public let isPending: Bool
    /// Whether the query is currently refetching in the background
    public let isRefetching: Bool
    /// Whether the query data is stale
    public let isStale: Bool
    /// Whether the query is paused due to being offline
    public let isPaused: Bool
    /// Number of times the query has been fetched
    public let dataUpdateCount: Int
    /// Number of times the query has failed
    public let errorUpdateCount: Int
    /// Number of consecutive failures
    public let failureCount: Int
    /// Reason for the last failure
    public let failureReason: QueryError?
    /// Timestamp when data was last updated
    public let dataUpdatedAt: Date?
    /// Timestamp when error was last updated
    public let errorUpdatedAt: Date?

    init(
        data: TData? = nil,
        error: QueryError? = nil,
        isLoading: Bool = false,
        isFetching: Bool = false,
        isSuccess: Bool = false,
        isError: Bool = false,
        isPending: Bool = true,
        isRefetching: Bool = false,
        isStale: Bool = true,
        isPaused: Bool = false,
        dataUpdateCount: Int = 0,
        errorUpdateCount: Int = 0,
        failureCount: Int = 0,
        failureReason: QueryError? = nil,
        dataUpdatedAt: Date? = nil,
        errorUpdatedAt: Date? = nil
    ) {
        self.data = data
        self.error = error
        self.isLoading = isLoading
        self.isFetching = isFetching
        self.isSuccess = isSuccess
        self.isError = isError
        self.isPending = isPending
        self.isRefetching = isRefetching
        self.isStale = isStale
        self.isPaused = isPaused
        self.dataUpdateCount = dataUpdateCount
        self.errorUpdateCount = errorUpdateCount
        self.failureCount = failureCount
        self.failureReason = failureReason
        self.dataUpdatedAt = dataUpdatedAt
        self.errorUpdatedAt = errorUpdatedAt
    }
}

// MARK: - Query Observer Class

/// Reactive observer that manages query subscriptions and provides SwiftUI-compatible state
/// Equivalent to TanStack Query's QueryObserver
/// This is the bridge between the core Query class and SwiftUI reactive updates
@MainActor
@Perceptible
public final class QueryObserver<TData: Sendable, TKey: QueryKey>: AnyQueryObserver {
    // MARK: - Public Properties

    /// Unique identifier for this observer
    public let id = QueryObserverIdentifier()

    /// Current result containing all query state
    @PerceptionIgnored
    public private(set) var result: QueryObserverResult<TData>

    /// Current query options
    @PerceptionIgnored
    public private(set) var options: QueryOptions<TData, QueryError, TKey>

    // MARK: - Convenience Properties (derived from result)

    /// The actual data returned by the query
    public var data: TData? { result.data }

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

    // MARK: - Private Properties

    /// Reference to the query client
    private let client: QueryClient

    /// Current query instance
    private var currentQuery: Query<TData, QueryError, TKey>?

    /// Whether the observer is currently subscribed
    private var isSubscribed = false

    /// Timer for stale timeout
    @PerceptionIgnored
    private nonisolated(unsafe) var staleTimer: Timer?

    /// Timer for refetch interval
    @PerceptionIgnored
    private nonisolated(unsafe) var refetchTimer: Timer?

    // MARK: - Initialization

    public init(client: QueryClient, options: QueryOptions<TData, QueryError, TKey>) {
        self.client = client
        self.options = options
        self.result = QueryObserverResult<TData>()

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
    public func setOptions(_ newOptions: QueryOptions<TData, QueryError, TKey>) {
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

    /// Manually refetch the query
    @discardableResult
    public func refetch(cancelRefetch: Bool = true) -> Task<TData?, Error> {
        return executeFetch(cancelRefetch: cancelRefetch)
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
        return AnyQueryResultWrapper(isStale: result.isStale)
    }

    public func onQueryUpdate() {
        updateResult()
    }

    public func isEnabled() -> Bool {
        return options.enabled
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
        let newQuery = client.buildQuery(options: options)

        if currentQuery !== newQuery {
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
        }
    }

    /// Update the result based on current query state
    private func updateResult() {
        guard let query = currentQuery else {
            result = QueryObserverResult<TData>()
            return
        }

        let queryState = query.state
        let fetchStatus = queryState.fetchStatus

        // Calculate derived state
        let hasData = queryState.data != nil
        let hasError = queryState.error != nil

        let isLoading = fetchStatus == .fetching && !hasData
        let isFetching = fetchStatus == .fetching
        let isPending = !hasData && !hasError
        let isSuccess = hasData && !hasError
        let isError = hasError
        let isRefetching = isFetching && hasData
        let isStale = query.isStale
        let isPaused = fetchStatus == .paused

        // Create new result
        result = QueryObserverResult(
            data: queryState.data,
            error: queryState.error,
            isLoading: isLoading,
            isFetching: isFetching,
            isSuccess: isSuccess,
            isError: isError,
            isPending: isPending,
            isRefetching: isRefetching,
            isStale: isStale,
            isPaused: isPaused,
            dataUpdateCount: queryState.dataUpdateCount,
            errorUpdateCount: queryState.errorUpdateCount,
            failureCount: queryState.fetchFailureCount,
            failureReason: queryState.fetchFailureReason,
            dataUpdatedAt: query.lastUpdated,
            errorUpdatedAt: queryState
                .errorUpdatedAt > 0 ? Date(timeIntervalSince1970: Double(queryState.errorUpdatedAt) / 1000.0) : nil
        )
    }

    /// Execute a fetch operation
    @discardableResult
    private func executeFetch(cancelRefetch: Bool = false) -> Task<TData?, Error> {
        return Task { @MainActor in
            guard let query = currentQuery else { return nil }

            // Update result to show fetching state
            updateResult()

            do {
                // TODO: Implement actual fetch in Query class
                // For now, we'll use a placeholder
                return try await query.fetch()
            } catch {
                // Update result to show error state
                updateResult()
                throw error
            }
        }
    }

    /// Determine if we should fetch when the observer first mounts
    private func shouldFetchOnMount() -> Bool {
        guard let query = currentQuery else { return false }
        guard options.enabled else { return false }

        let hasData = query.state.data != nil
        let isStale = query.isStale

        // Always fetch if no data
        if !hasData {
            return true
        }

        // Fetch based on refetchOnAppear setting
        switch options.refetchOnAppear {
        case .always:
            return true
        case .ifStale:
            return isStale
        case .never:
            return false
        }
    }

    /// Determine if we should fetch when options change
    private func shouldFetchOnOptionsChange(
        previousQuery: Query<TData, QueryError, TKey>?,
        previousOptions: QueryOptions<TData, QueryError, TKey>,
        newQuery: Query<TData, QueryError, TKey>?,
        newOptions: QueryOptions<TData, QueryError, TKey>
    ) -> Bool {
        // If query key changed, always fetch
        if previousQuery !== newQuery {
            return shouldFetchOnMount()
        }

        // If enabled state changed to true, fetch
        if !previousOptions.enabled, newOptions.enabled {
            return shouldFetchOnMount()
        }

        // If query function changed, fetch
        // Note: We can't easily compare functions in Swift, so we skip this check

        return false
    }

    /// Helper to determine if should fetch based on a trigger condition
    private func shouldFetchOn(
        query: Query<TData, QueryError, TKey>,
        options: QueryOptions<TData, QueryError, TKey>,
        trigger: Bool
    ) -> Bool {
        guard options.enabled else { return false }
        guard trigger else { return false }

        let isStale = query.isStale
        return isStale
    }

    /// Update timers based on current options
    private func updateTimers() {
        clearTimers()

        // Set up stale timeout
        if options.staleTime > 0, let query = currentQuery, query.state.data != nil {
            let staleTime = options.staleTime
            staleTimer = Timer.scheduledTimer(withTimeInterval: staleTime, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateResult()
                }
            }
        }

        // Set up refetch interval - TODO: Implement refetch interval logic
    }

    /// Clear all timers
    private func clearTimers() {
        staleTimer?.invalidate()
        staleTimer = nil

        refetchTimer?.invalidate()
        refetchTimer = nil
    }
}

// MARK: - Supporting Types

/// Wrapper for AnyQueryResult protocol
private struct AnyQueryResultWrapper: AnyQueryResult {
    let isStale: Bool
}

// MARK: - Query Extension for Fetch

extension Query {
    /// Fetch method to be implemented
    func fetch() async throws -> TData? {
        // TODO: Implementation will be added when we implement the full fetch logic
        // For now, return current data
        return state.data
    }
}
