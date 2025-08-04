// QueryClient.swift - Central client managing all queries and mutations
// Based on TanStack Query's QueryClient class

import Foundation
import Perception

// MARK: - Query Client Configuration

/// Configuration for creating a QueryClient instance
/// Equivalent to TanStack Query's QueryClientConfig
public struct QueryClientConfig {
    /// Query cache instance to use (creates default if nil)
    public let queryCache: QueryCache?
    /// Default options for all queries
    public let defaultOptions: DefaultQueryOptions?

    public init(
        queryCache: QueryCache? = nil,
        defaultOptions: DefaultQueryOptions? = nil
    ) {
        self.queryCache = queryCache
        self.defaultOptions = defaultOptions
    }
}

/// Default options applied to all queries
/// Equivalent to TanStack Query's DefaultOptions
public struct DefaultQueryOptions {
    /// Default query configuration
    public let queries: DefaultQueryConfig?
    /// Default mutation configuration (for future implementation)
    public let mutations: DefaultMutationConfig?

    public init(
        queries: DefaultQueryConfig? = nil,
        mutations: DefaultMutationConfig? = nil
    ) {
        self.queries = queries
        self.mutations = mutations
    }
}

/// Default configuration for queries
public struct DefaultQueryConfig {
    /// Default stale time for all queries
    public let staleTime: TimeInterval?
    /// Default garbage collection time
    public let gcTime: TimeInterval?
    /// Default retry configuration
    public let retryConfig: RetryConfig?
    /// Default network mode
    public let networkMode: NetworkMode?
    /// Default refetch triggers
    public let refetchTriggers: RefetchTriggers?

    public init(
        staleTime: TimeInterval? = nil,
        gcTime: TimeInterval? = nil,
        retryConfig: RetryConfig? = nil,
        networkMode: NetworkMode? = nil,
        refetchTriggers: RefetchTriggers? = nil
    ) {
        self.staleTime = staleTime
        self.gcTime = gcTime
        self.retryConfig = retryConfig
        self.networkMode = networkMode
        self.refetchTriggers = refetchTriggers
    }
}

/// Default configuration for mutations (placeholder for future implementation)
public struct DefaultMutationConfig {
    public init() {}
}

// MARK: - Query Client Class

/// Central client that manages all queries and mutations
/// Equivalent to TanStack Query's QueryClient
/// This is the main entry point for query operations
@MainActor
public final class QueryClient {
    // MARK: - Private Properties

    /// Query cache instance that stores all queries
    private let queryCache: QueryCache

    /// Default options for all queries
    private let defaultOptions: DefaultQueryOptions

    /// Mount count for tracking active usage
    private var mountCount = 0

    /// Subscriptions for lifecycle events
    private var focusUnsubscriber: (() -> Void)?
    private var onlineUnsubscriber: (() -> Void)?

    // MARK: - Initialization

    public init(config: QueryClientConfig = QueryClientConfig()) {
        self.queryCache = config.queryCache ?? QueryCache()
        self.defaultOptions = config.defaultOptions ?? DefaultQueryOptions()

        // Register cache with garbage collector
        GarbageCollector.shared.register(queryCache)
    }

    // MARK: - Lifecycle Management

    /// Mount the client to start listening to system events
    /// Should be called when the client becomes active
    public func mount() {
        mountCount += 1
        if mountCount != 1 { return }

        // Start garbage collector
        GarbageCollector.shared.start()

        // TODO: Subscribe to focus manager
        // focusUnsubscriber = FocusManager.shared.subscribe { [weak self] focused in
        //     if focused {
        //         Task { @MainActor in
        //             self?.queryCache.onFocus()
        //         }
        //     }
        // }

        // TODO: Subscribe to online manager
        // onlineUnsubscriber = OnlineManager.shared.subscribe { [weak self] online in
        //     if online {
        //         Task { @MainActor in
        //             self?.queryCache.onOnline()
        //         }
        //     }
        // }
    }

    /// Unmount the client and stop listening to system events
    /// Should be called when the client is no longer needed
    public func unmount() {
        mountCount -= 1
        if mountCount != 0 { return }

        focusUnsubscriber?()
        focusUnsubscriber = nil

        onlineUnsubscriber?()
        onlineUnsubscriber = nil
    }

    // MARK: - Query Management

    /// Get query data imperatively (non-reactive)
    /// Use this in callbacks or functions where you need the latest data
    /// For reactive UI updates, use QueryObserver instead
    public func getQueryData<TData: Sendable, TKey: QueryKey>(
        queryKey: TKey
    ) -> TData? {
        let queryHash = hashQueryKey(queryKey)
        guard let query = queryCache.get(queryHash: queryHash) as? Query<TData, TKey> else {
            QueryLogger.shared.logDataCacheMiss(hash: queryHash)
            return nil
        }
        QueryLogger.shared.logDataCacheHit(hash: queryHash)
        return query.state.data
    }

    /// Set query data imperatively
    /// This will update existing queries and notify observers
    @discardableResult
    public func setQueryData<TData: Sendable>(
        queryKey: some QueryKey,
        data: TData
    ) -> TData {
        let query = ensureQuery(queryKey: queryKey, data: data)
        return query.setData(data)
    }

    /// Get the current state of a query
    public func getQueryState<TData: Sendable, TKey: QueryKey>(
        queryKey: TKey
    ) -> QueryState<TData>? {
        let queryHash = hashQueryKey(queryKey)
        guard let query = queryCache.get(queryHash: queryHash) as? Query<TData, TKey> else {
            QueryLogger.shared.logStateCacheMiss(hash: queryHash)
            return nil
        }
        QueryLogger.shared.logStateCacheHit(hash: queryHash)
        return query.state
    }

    /// Build or get existing query from cache
    /// This is used internally by observers to get query instances
    public func buildQuery<TData: Sendable, TKey: QueryKey>(
        options: QueryOptions<TData, TKey>
    ) -> Query<TData, TKey> {
        let queryHash = hashQueryKey(options.queryKey)

        if let existingQuery = queryCache.get(queryHash: queryHash) as? Query<TData, TKey> {
            // Cache hit - log for debugging
            QueryLogger.shared.logCacheHit(hash: queryHash)

            // Update options on existing query
            existingQuery.setOptions(options)
            return existingQuery
        }

        // Cache miss - create new query
        QueryLogger.shared.logCacheMiss(hash: queryHash)

        let config = QueryConfig<TData, TKey>(
            queryKey: options.queryKey,
            queryHash: queryHash,
            options: options,
            defaultOptions: mergeWithDefaults(options),
            state: nil as QueryState<TData>?
        )

        let query = Query<TData, TKey>(config: config, cache: queryCache)
        queryCache.add(query)

        return query
    }

    /// Ensure a query exists for the given key, creating one if necessary
    private func ensureQuery<TData: Sendable, TKey: QueryKey>(
        queryKey: TKey,
        data: TData
    ) -> Query<TData, TKey> {
        let options = QueryOptions<TData, TKey>(
            queryKey: queryKey,
            queryFn: { _ in data }, // Dummy function for imperative data setting
            retryConfig: defaultOptions.queries?.retryConfig ?? RetryConfig(),
            networkMode: defaultOptions.queries?.networkMode ?? .online,
            staleTime: defaultOptions.queries?.staleTime ?? 0,
            gcTime: defaultOptions.queries?.gcTime ?? defaultGcTime,
            refetchTriggers: defaultOptions.queries?.refetchTriggers ?? .default,
            refetchOnAppear: .always,
            initialData: nil,
            initialDataFunction: nil,
            structuralSharing: true,
            meta: nil,
            enabled: true
        )

        return buildQuery(options: options)
    }

    // MARK: - Query Operations

    /// Remove queries from the cache
    /// Optionally filter by query key patterns
    public func removeQueries(
        queryKey: (some QueryKey)? = nil,
        exact: Bool = false
    ) {
        let queriesToRemove: [AnyQuery]

        if let queryKey {
            let targetHash = hashQueryKey(queryKey)
            if exact {
                // Remove exact match only
                queriesToRemove = queryCache.allQueries.filter { $0.queryHash == targetHash }
            } else {
                // Remove queries that start with the key (partial matching)
                queriesToRemove = queryCache.allQueries.filter { query in
                    query.queryHash.hasPrefix(targetHash)
                }
            }
        } else {
            // Remove all queries
            queriesToRemove = queryCache.allQueries
        }

        for query in queriesToRemove {
            queryCache.remove(query)
        }
    }

    /// Invalidate queries, marking them as stale
    /// This will trigger refetches for active queries
    public func invalidateQueries(
        queryKey: (some QueryKey)? = nil,
        exact: Bool = false,
        refetch: Bool = true
    ) async {
        let queriesToInvalidate: [AnyQuery]

        if let queryKey {
            let targetHash = hashQueryKey(queryKey)
            if exact {
                // Invalidate exact match only
                queriesToInvalidate = queryCache.allQueries.filter { $0.queryHash == targetHash }
            } else {
                // Invalidate queries that start with the key (partial matching)
                queriesToInvalidate = queryCache.allQueries.filter { query in
                    query.queryHash.hasPrefix(targetHash)
                }
            }
        } else {
            // Invalidate all queries
            queriesToInvalidate = queryCache.allQueries
        }

        // Invalidate all matching queries
        for anyQuery in queriesToInvalidate {
            // Type erasure makes this tricky - we need to call invalidate on the concrete type
            // For now, we'll use a protocol method
            if let query = anyQuery as? any QueryInvalidatable {
                query.invalidate()
            }
        }

        // Optionally trigger refetch for active queries
        if refetch {
            await refetchQueries(queryKey: queryKey, exact: exact)
        }
    }

    /// Refetch queries that match the given criteria
    public func refetchQueries(
        queryKey: (some QueryKey)? = nil,
        exact: Bool = false
    ) async {
        let queriesToRefetch: [AnyQuery]

        if let queryKey {
            let targetHash = hashQueryKey(queryKey)
            if exact {
                // Refetch exact match only
                queriesToRefetch = queryCache.allQueries.filter { $0.queryHash == targetHash }
            } else {
                // Refetch queries that start with the key (partial matching)
                queriesToRefetch = queryCache.allQueries.filter { query in
                    query.queryHash.hasPrefix(targetHash)
                }
            }
        } else {
            // Refetch all queries
            queriesToRefetch = queryCache.allQueries
        }

        // Refetch all matching queries that are active
        for anyQuery in queriesToRefetch {
            if let query = anyQuery as? any QueryRefetchable,
               !query.isDisabled() {
                do {
                    try await query.fetch()
                } catch {
                    // Errors are handled within the query
                }
            }
        }
    }

    /// Reset queries to their initial state
    public func resetQueries(
        queryKey: (some QueryKey)? = nil,
        exact: Bool = false
    ) async {
        let queriesToReset: [AnyQuery]

        if let queryKey {
            let targetHash = hashQueryKey(queryKey)
            if exact {
                queriesToReset = queryCache.allQueries.filter { $0.queryHash == targetHash }
            } else {
                queriesToReset = queryCache.allQueries.filter { query in
                    query.queryHash.hasPrefix(targetHash)
                }
            }
        } else {
            queriesToReset = queryCache.allQueries
        }

        // Reset all matching queries
        for anyQuery in queriesToReset {
            if let query = anyQuery as? any QueryResettable {
                query.reset()
            }
        }

        // Refetch active queries after reset
        await refetchQueries(queryKey: queryKey, exact: exact)
    }

    /// Cancel ongoing queries
    public func cancelQueries(
        queryKey: (some QueryKey)? = nil,
        exact: Bool = false
    ) async {
        let queriesToCancel: [AnyQuery]

        if let queryKey {
            let targetHash = hashQueryKey(queryKey)
            if exact {
                queriesToCancel = queryCache.allQueries.filter { $0.queryHash == targetHash }
            } else {
                queriesToCancel = queryCache.allQueries.filter { query in
                    query.queryHash.hasPrefix(targetHash)
                }
            }
        } else {
            queriesToCancel = queryCache.allQueries
        }

        // Cancel all matching queries
        for anyQuery in queriesToCancel {
            if let query = anyQuery as? any QueryCancellable {
                query.cancel()
            }
        }
    }

    /// Clear all queries and data from the cache
    public func clear() {
        queryCache.clear()
    }

    // MARK: - Cache Access

    /// Get access to the underlying query cache
    /// This is used by observers and other internal components
    public var cache: QueryCache {
        queryCache
    }

    // MARK: - Private Helpers

    /// Merge query options with defaults
    private func mergeWithDefaults<TData: Sendable, TKey: QueryKey>(
        _ options: QueryOptions<TData, TKey>
    ) -> QueryOptions<TData, TKey> {
        guard let defaults = defaultOptions.queries else { return options }

        return QueryOptions(
            queryKey: options.queryKey,
            queryFn: options.queryFn,
            retryConfig: defaults.retryConfig ?? options.retryConfig,
            networkMode: defaults.networkMode ?? options.networkMode,
            staleTime: defaults.staleTime ?? options.staleTime,
            gcTime: defaults.gcTime ?? options.gcTime,
            refetchTriggers: defaults.refetchTriggers ?? options.refetchTriggers,
            refetchOnAppear: options.refetchOnAppear,
            initialData: options.initialData,
            initialDataFunction: options.initialDataFunction,
            structuralSharing: options.structuralSharing,
            meta: options.meta,
            enabled: options.enabled
        )
    }

    /// Create a consistent hash for a query key
    private func hashQueryKey(_ key: some QueryKey) -> String {
        key.queryHash
    }
}

// MARK: - Query Protocols for Type Erasure

/// Protocol for queries that can be invalidated
@MainActor
protocol QueryInvalidatable {
    func invalidate()
}

/// Protocol for queries that can be refetched
@MainActor
protocol QueryRefetchable {
    func isDisabled() -> Bool
    func fetch() async throws
}

/// Protocol for queries that can be reset
@MainActor
protocol QueryResettable {
    func reset()
}

/// Protocol for queries that can be cancelled
@MainActor
protocol QueryCancellable {
    func cancel()
}

// MARK: - Query Protocol Conformance

extension Query: QueryInvalidatable, QueryRefetchable, QueryResettable, QueryCancellable {
    // The fetch() method is implemented in QueryObserver.swift
}

// MARK: - Singleton Provider

/// Global query client provider for easy access
/// This provides a shared instance but allows custom clients via environment
@MainActor
public final class QueryClientProvider {
    /// Shared instance for global access
    public static let shared = QueryClientProvider()

    /// The query client instance
    public let queryClient: QueryClient

    private init() {
        self.queryClient = QueryClient()
        // Mount the client immediately
        queryClient.mount()
    }

    deinit {
        // Note: We can't call unmount() in deinit due to MainActor isolation
        // The client will clean up automatically when deallocated
    }
}
