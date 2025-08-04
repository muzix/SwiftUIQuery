// UseInfiniteQuery.swift - SwiftUI view component for reactive infinite query management
// Based on TanStack Query's useInfiniteQuery hook

import SwiftUI
import Perception

// MARK: - Infinite Query Result Wrapper

/// Extended infinite query result that includes pagination functionality
/// This provides the same interface as InfiniteQueryObserverResult but adds action methods
public struct UseInfiniteQueryResult<TData: Sendable, TPageParam: Sendable & Codable> {
    /// The underlying infinite query observer result
    private let result: InfiniteQueryObserverResult<TData, TPageParam>
    /// Refetch function from the observer (full refetch)
    private let _refetch: @Sendable (Bool) async throws -> InfiniteData<TData, TPageParam>?
    /// Fetch next page function
    private let _fetchNextPage: @Sendable () async -> InfiniteQueryObserverResult<TData, TPageParam>
    /// Fetch previous page function
    private let _fetchPreviousPage: @Sendable () async -> InfiniteQueryObserverResult<TData, TPageParam>

    init(
        result: InfiniteQueryObserverResult<TData, TPageParam>,
        refetch: @escaping @Sendable (Bool) async throws -> InfiniteData<TData, TPageParam>?,
        fetchNextPage: @escaping @Sendable () async -> InfiniteQueryObserverResult<TData, TPageParam>,
        fetchPreviousPage: @escaping @Sendable () async -> InfiniteQueryObserverResult<TData, TPageParam>
    ) {
        self.result = result
        self._refetch = refetch
        self._fetchNextPage = fetchNextPage
        self._fetchPreviousPage = fetchPreviousPage
    }

    // MARK: - Forward all properties from InfiniteQueryObserverResult

    /// The infinite data containing all pages
    public var data: InfiniteData<TData, TPageParam>? { result.data }

    /// The error if the query failed
    public var error: QueryError? { result.error }

    /// Number of times the query has been fetched
    public var dataUpdateCount: Int { result.dataUpdateCount }

    /// Number of times the query has failed
    public var errorUpdateCount: Int { result.errorUpdateCount }

    /// Number of consecutive failures
    public var failureCount: Int { result.failureCount }

    /// Reason for the last failure
    public var failureReason: QueryError? { result.failureReason }

    /// Timestamp when data was last updated
    public var dataUpdatedAt: Date? { result.dataUpdatedAt }

    /// Timestamp when error was last updated
    public var errorUpdatedAt: Date? { result.errorUpdatedAt }

    /// Whether the query is currently fetching (including background refetch)
    public var isFetching: Bool { result.isFetching }

    /// Whether the query is paused due to being offline
    public var isPaused: Bool { result.isPaused }

    /// Whether the query is in pending state (no data yet)
    public var isPending: Bool { result.isPending }

    /// Whether the query is successful and has data
    public var isSuccess: Bool { result.isSuccess }

    /// Whether the query failed with an error
    public var isError: Bool { result.isError }

    /// Whether the query is currently loading for the first time
    public var isLoading: Bool { result.isLoading }

    /// Whether the query is currently refetching in the background
    public var isRefetching: Bool { result.isRefetching }

    /// Whether the query data is stale
    public var isStale: Bool { result.isStale }

    // MARK: - Infinite Query Specific Properties

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

    // MARK: - Action Methods

    /// Refetch all pages (full refetch)
    @discardableResult
    public func refetch(cancelRefetch: Bool = true) async throws -> InfiniteData<TData, TPageParam>? {
        try await _refetch(cancelRefetch)
    }

    /// Fetch the next page
    @discardableResult
    public func fetchNextPage() async -> InfiniteQueryObserverResult<TData, TPageParam> {
        await _fetchNextPage()
    }

    /// Fetch the previous page
    @discardableResult
    public func fetchPreviousPage() async -> InfiniteQueryObserverResult<TData, TPageParam> {
        await _fetchPreviousPage()
    }
}

// MARK: - UseInfiniteQuery View Component

/// SwiftUI view component that provides reactive infinite query functionality
/// Equivalent to TanStack Query's useInfiniteQuery hook
/// This is the main interface for using infinite queries in SwiftUI
public struct UseInfiniteQuery<
    TData: Sendable,
    TKey: QueryKey,
    TPageParam: Sendable & Codable,
    Content: View
>: View {
    // MARK: - Private Properties

    /// Infinite query observer that manages the query lifecycle
    @StateObject private var observer: InfiniteQueryObserver<TData, TKey, TPageParam>

    /// Current infinite query options (can change during view lifecycle)
    private let options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>

    /// Optional query client override
    private let queryClient: QueryClient?

    #if DEBUG
        /// Observer access for testing purposes
        var testObserver: InfiniteQueryObserver<TData, TKey, TPageParam> { observer }
    #endif

    /// Content builder that receives the infinite query result
    private let content: (UseInfiniteQueryResult<TData, TPageParam>) -> Content

    /// Environment query client (takes precedence over passed client)
    @Environment(\.queryClient) private var environmentQueryClient

    // MARK: - Initialization

    /// Initialize UseInfiniteQuery with infinite query options and content builder
    /// - Parameters:
    ///   - options: Infinite query configuration options
    ///   - queryClient: Optional query client (uses shared instance if nil)
    ///   - content: View builder that receives the infinite query result
    public init(
        options: InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>,
        queryClient: QueryClient? = nil,
        @ViewBuilder content: @escaping (UseInfiniteQueryResult<TData, TPageParam>) -> Content
    ) {
        // Store options and client for later use
        self.options = options
        self.queryClient = queryClient
        // Note: Environment client will be resolved in body, use passed client or shared for initial observer
        let client = queryClient ?? QueryClientProvider.shared.queryClient
        self._observer = StateObject(wrappedValue: InfiniteQueryObserver(client: client, options: options))
        self.content = content
    }

    /// Convenience initializer with explicit parameters
    /// - Parameters:
    ///   - queryKey: Unique identifier for the query
    ///   - queryFn: Function that fetches the data pages
    ///   - getNextPageParam: Function to determine the next page parameter
    ///   - getPreviousPageParam: Function to determine the previous page parameter
    ///   - initialPageParam: Initial page parameter for the first page
    ///   - maxPages: Maximum number of pages to retain
    ///   - staleTime: Time before data is considered stale (default: 0)
    ///   - gcTime: Time before unused data is garbage collected (default: 5 minutes)
    ///   - enabled: Whether the query should execute automatically (default: true)
    ///   - queryClient: Optional query client (uses shared instance if nil)
    ///   - content: View builder that receives the infinite query result
    public init(
        queryKey: TKey,
        queryFn: @escaping InfiniteQueryFunction<TData, TKey, TPageParam>,
        getNextPageParam: GetNextPageParamFunction<TData, TPageParam>? = nil,
        getPreviousPageParam: GetPreviousPageParamFunction<TData, TPageParam>? = nil,
        initialPageParam: TPageParam? = nil,
        maxPages: Int? = nil,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = defaultGcTime,
        enabled: Bool = true,
        queryClient: QueryClient? = nil,
        @ViewBuilder content: @escaping (UseInfiniteQueryResult<TData, TPageParam>) -> Content
    ) {
        let options = InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>(
            queryKey: queryKey,
            queryFn: queryFn,
            getNextPageParam: getNextPageParam,
            getPreviousPageParam: getPreviousPageParam,
            initialPageParam: initialPageParam,
            maxPages: maxPages,
            retryConfig: RetryConfig(),
            networkMode: NetworkMode.online,
            staleTime: staleTime,
            gcTime: gcTime,
            refetchTriggers: RefetchTriggers.default,
            refetchOnAppear: RefetchOnAppear.ifStale,
            structuralSharing: true,
            meta: nil as QueryMeta?,
            enabled: enabled
        )

        // Store options and client for later use
        self.options = options
        self.queryClient = queryClient
        let client = queryClient ?? QueryClientProvider.shared.queryClient
        self._observer = StateObject(wrappedValue: InfiniteQueryObserver(client: client, options: options))
        self.content = content
    }

    // MARK: - View Body

    public var body: some View {
        WithPerceptionTracking {
            let useInfiniteQueryResult = UseInfiniteQueryResult(
                result: observer.result,
                refetch: { [weak observer] cancelRefetch in
                    guard let observer else { return nil }
                    return try await observer.refetch(cancelRefetch: cancelRefetch).value
                },
                fetchNextPage: { [weak observer] in
                    guard let observer else {
                        return InfiniteQueryObserverResult<TData, TPageParam>(
                            queryState: QueryState<InfiniteData<TData, TPageParam>>(
                                data: InfiniteData<TData, TPageParam>(),
                                status: .pending
                            ),
                            isStale: true
                        )
                    }
                    return await observer.fetchNextPage().value
                },
                fetchPreviousPage: { [weak observer] in
                    guard let observer else {
                        return InfiniteQueryObserverResult<TData, TPageParam>(
                            queryState: QueryState<InfiniteData<TData, TPageParam>>(
                                data: InfiniteData<TData, TPageParam>(),
                                status: .pending
                            ),
                            isStale: true
                        )
                    }
                    return await observer.fetchPreviousPage().value
                }
            )
            VStack {
                content(useInfiniteQueryResult)
            }
        }
        .onAppear {
            // Use environment client if available, otherwise keep current observer
//            let finalClient = environmentQueryClient ?? queryClient ?? QueryClientProvider.shared.queryClient
//            if observer.client !== finalClient {
//                // Create new observer with correct client
//                let newObserver = InfiniteQueryObserver(client: finalClient, options: options)
//                observer = newObserver
//            }

            // Update observer options to current options
            observer.setOptions(options)
            observer.subscribe()
        }
        .onDisappear {
            observer.unsubscribe()
        }
        .onChange(of: options.queryKey) { newKey in
            let newOptions = InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>(
                queryKey: newKey,
                queryFn: options.queryFn,
                getNextPageParam: options.getNextPageParam,
                getPreviousPageParam: options.getPreviousPageParam,
                initialPageParam: options.initialPageParam,
                maxPages: options.maxPages,
                retryConfig: options.retryConfig,
                networkMode: options.networkMode,
                staleTime: options.staleTime,
                gcTime: options.gcTime,
                refetchTriggers: options.refetchTriggers,
                refetchOnAppear: options.refetchOnAppear,
                structuralSharing: options.structuralSharing,
                meta: options.meta,
                enabled: options.enabled
            )
            observer.setOptions(newOptions)
        }
        .onChange(of: options.enabled) { newEnabled in
            // Update observer options when enabled state changes
            // Create new options using the new enabled value
            let newOptions = InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>(
                queryKey: options.queryKey,
                queryFn: options.queryFn,
                getNextPageParam: options.getNextPageParam,
                getPreviousPageParam: options.getPreviousPageParam,
                initialPageParam: options.initialPageParam,
                maxPages: options.maxPages,
                retryConfig: options.retryConfig,
                networkMode: options.networkMode,
                staleTime: options.staleTime,
                gcTime: options.gcTime,
                refetchTriggers: options.refetchTriggers,
                refetchOnAppear: options.refetchOnAppear,
                structuralSharing: options.structuralSharing,
                meta: options.meta,
                enabled: newEnabled
            )
            observer.setOptions(newOptions)
        }
        .onChange(of: options.staleTime) { newStaleTime in
            // Update observer options when staleTime changes
            let newOptions = InfiniteQueryOptions<TData, QueryError, TKey, TPageParam>(
                queryKey: options.queryKey,
                queryFn: options.queryFn,
                getNextPageParam: options.getNextPageParam,
                getPreviousPageParam: options.getPreviousPageParam,
                initialPageParam: options.initialPageParam,
                maxPages: options.maxPages,
                retryConfig: options.retryConfig,
                networkMode: options.networkMode,
                staleTime: newStaleTime,
                gcTime: options.gcTime,
                refetchTriggers: options.refetchTriggers,
                refetchOnAppear: options.refetchOnAppear,
                structuralSharing: options.structuralSharing,
                meta: options.meta,
                enabled: options.enabled
            )
            observer.setOptions(newOptions)
        }
    }
}

// MARK: - SwiftUI Convenience Extensions

/// Additional convenience methods for SwiftUI integration
extension UseInfiniteQuery {
    /// Create a UseInfiniteQuery with simple parameters for common use cases
    /// - Parameters:
    ///   - queryKey: String-based query key
    ///   - queryFn: Function that fetches page data
    ///   - getNextPageParam: Function to get next page parameter from pages
    ///   - content: View builder that receives the query result
    public init(
        queryKey: String,
        queryFn: @escaping @Sendable (String, TPageParam?) async throws -> TData,
        getNextPageParam: @escaping GetNextPageParamFunction<TData, TPageParam>,
        @ViewBuilder content: @escaping (UseInfiniteQueryResult<TData, TPageParam>) -> Content
    ) where TKey == String {
        let options = InfiniteQueryOptions<TData, QueryError, String, TPageParam>(
            queryKey: queryKey,
            queryFn: queryFn,
            getNextPageParam: getNextPageParam
        )

        self.init(
            options: options,
            content: content
        )
    }
}
