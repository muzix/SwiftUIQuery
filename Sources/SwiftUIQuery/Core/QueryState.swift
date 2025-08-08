import Foundation

// MARK: - Query State

/// Complete state of a query instance
/// Equivalent to TanStack Query's QueryState
/// This is the single source of truth for query state - QueryObserverResult computes derived properties from this
public struct QueryState<TData: Sendable>: Sendable {
    /// The actual data returned by the query function
    public let data: TData?
    /// Number of times data has been updated
    public let dataUpdateCount: Int
    /// Timestamp when data was last updated (milliseconds since epoch)
    public let dataUpdatedAt: Int64
    /// The error object if the query failed
    public let error: QueryError?
    /// Number of times an error has occurred
    public let errorUpdateCount: Int
    /// Timestamp when error was last updated (milliseconds since epoch)
    public let errorUpdatedAt: Int64
    /// Number of consecutive failures
    public let fetchFailureCount: Int
    /// The failure reason of the last fetch attempt
    public let fetchFailureReason: QueryError?
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
        error: QueryError? = nil,
        errorUpdateCount: Int = 0,
        errorUpdatedAt: Int64 = 0,
        fetchFailureCount: Int = 0,
        fetchFailureReason: QueryError? = nil,
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
    public static func defaultState() -> QueryState<TData> {
        QueryState<TData>()
    }

    /// Create a copy with updated data
    public func withData(_ newData: TData?) -> QueryState<TData> {
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
    public func withError(_ newError: QueryError?) -> QueryState<TData> {
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
    public func withFetchStatus(_ newFetchStatus: FetchStatus) -> QueryState<TData> {
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
    public func invalidated() -> QueryState<TData> {
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
