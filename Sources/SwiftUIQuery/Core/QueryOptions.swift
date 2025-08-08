import Foundation

// MARK: - Constants

/// Default garbage collection time in seconds (5 minutes)
public let defaultGcTime: TimeInterval = 5 * 60

// MARK: - Query Function Types

/// Function signature for query functions
public typealias QueryFunction<TData: Sendable, TKey: QueryKey> = @Sendable (TKey) async throws -> TData

/// Function signature for initial data providers
public typealias InitialDataFunction<TData: Sendable> = @Sendable () -> TData?

// MARK: - Query Options

/// Configuration options for queries
/// Equivalent to TanStack Query's QueryOptions
public struct QueryOptions<TData: Sendable, TKey: QueryKey>: Sendable, Equatable {
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

    public static func == (lhs: QueryOptions<TData, TKey>, rhs: QueryOptions<TData, TKey>) -> Bool {
        lhs.queryKey == rhs.queryKey &&
            lhs.staleTime == rhs.staleTime &&
            lhs.gcTime == rhs.gcTime &&
            lhs.refetchTriggers == rhs.refetchTriggers &&
            lhs.refetchOnAppear == rhs.refetchOnAppear &&
            lhs.enabled == rhs.enabled
    }

    public init(
        queryKey: TKey,
        queryFn: @escaping QueryFunction<TData, TKey>,
        retryConfig: RetryConfig = RetryConfig(),
        networkMode: NetworkMode = .online,
        staleTime: TimeInterval = 0, // Immediately stale by default
        gcTime: TimeInterval = 5, // 5 minutes default
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
