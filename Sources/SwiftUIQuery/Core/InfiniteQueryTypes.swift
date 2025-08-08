import Foundation

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
    TPageParam: Sendable & Codable & Equatable
>: Sendable, Equatable {
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

    public static func == (
        lhs: InfiniteQueryOptions<TData, TError, TKey, TPageParam>,
        rhs: InfiniteQueryOptions<TData, TError, TKey, TPageParam>
    ) -> Bool {
        lhs.queryKey == rhs.queryKey &&
            lhs.initialPageParam == rhs.initialPageParam &&
            lhs.maxPages == rhs.maxPages &&
            lhs.staleTime == rhs.staleTime &&
            lhs.gcTime == rhs.gcTime &&
            lhs.refetchTriggers == rhs.refetchTriggers &&
            lhs.refetchOnAppear == rhs.refetchOnAppear &&
            lhs.enabled == rhs.enabled
    }

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
        gcTime: TimeInterval = defaultGcTime,
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
