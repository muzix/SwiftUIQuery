//
//  QueryClient.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import SwiftUI

/// The central client that manages all queries and mutations
@MainActor
public final class QueryClient: ObservableObject {
    // MARK: - Properties

    /// The query cache
    private let queryCache: QueryCache

    /// Default query options
    public var defaultOptions: QueryOptions

    // MARK: - Initialization

    /// Initialize a new QueryClient
    /// - Parameter defaultOptions: Default options for all queries
    public init(defaultOptions: QueryOptions = .default) {
        self.defaultOptions = defaultOptions
        self.queryCache = QueryCache()
    }

    // MARK: - Query Management

    /// Get or create a query
    func getQuery<T: Sendable>(
        key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        options: QueryOptions,
        reportError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) -> QueryInstance<T> {
        queryCache.getOrCreateQuery(
            key: key,
            fetch: fetch,
            options: mergeOptions(options),
            reportError: reportError
        )
    }

    // MARK: - Invalidation

    /// Invalidate queries matching the filter
    /// - Parameters:
    ///   - filter: Optional filter to match specific queries
    ///   - refetchType: How to refetch after invalidation (default: .active)
    public func invalidateQueries(
        filter: QueryFilter? = nil,
        refetchType: RefetchType = .active
    ) async {
        let queries = queryCache.findAll(filter: filter)

        // Mark all matching queries as invalidated
        for query in queries {
            query.invalidate()
        }

        // Refetch based on type
        switch refetchType {
        case .none:
            break
        case .active:
            // Only refetch queries with active observers
            let activeQueries = queries.filter { $0.isActive() }
            await withTaskGroup(of: Void.self) { group in
                for query in activeQueries {
                    group.addTask { await query.fetch() }
                }
            }
        case .inactive:
            // Only refetch queries without active observers
            let inactiveQueries = queries.filter { !$0.isActive() }
            await withTaskGroup(of: Void.self) { group in
                for query in inactiveQueries {
                    group.addTask { await query.fetch() }
                }
            }
        case .all:
            // Refetch all queries
            await withTaskGroup(of: Void.self) { group in
                for query in queries {
                    group.addTask { await query.fetch() }
                }
            }
        }
    }

    /// Refetch queries matching the filter
    /// - Parameter filter: Optional filter to match specific queries
    public func refetchQueries(filter: QueryFilter? = nil) async {
        let queries = queryCache.findAll(filter: filter)

        // Refetch all matching queries in parallel
        await withTaskGroup(of: Void.self) { group in
            for query in queries {
                group.addTask { await query.fetch() }
            }
        }
    }

    /// Reset queries matching the filter to their initial state
    /// - Parameter filter: Optional filter to match specific queries
    public func resetQueries(filter: QueryFilter? = nil) {
        let queries = queryCache.findAll(filter: filter)

        for query in queries {
            query.reset()
        }
    }

    /// Remove queries from the cache
    /// - Parameter filter: Optional filter to match specific queries
    public func removeQueries(filter: QueryFilter? = nil) {
        queryCache.removeQueries(filter: filter)
    }

    /// Clear the entire cache
    public func clear() {
        queryCache.clear()
    }

    /// Get all queries in the cache
    public func getAllQueries() -> [AnyQueryInstance] {
        queryCache.findAll(filter: nil)
    }

    // MARK: - Private Methods

    private func mergeOptions(_ options: QueryOptions) -> QueryOptions {
        // Merge provided options with default options
        var merged = options

        // Only override if not explicitly set
        if options.staleTime == defaultOptions.staleTime {
            merged.staleTime = defaultOptions.staleTime
        }

        return merged
    }
}

// MARK: - Query Filter

/// Filter for finding queries
public struct QueryFilter: Sendable {
    /// Match queries by exact key
    public let key: (any QueryKey)?

    /// Match queries by predicate
    public let predicate: (@Sendable (any QueryKey) -> Bool)?

    /// Match all queries
    public static let all = Self(key: nil, predicate: nil)

    /// Match queries by exact key
    public static func key(_ key: any QueryKey) -> Self {
        Self(key: key, predicate: nil)
    }

    /// Match queries by predicate
    public static func predicate(_ predicate: @escaping @Sendable (any QueryKey) -> Bool) -> Self {
        Self(key: nil, predicate: predicate)
    }
}

// MARK: - Refetch Type

/// How to refetch queries after invalidation
public enum RefetchType {
    /// Don't refetch
    case none
    /// Only refetch active queries (with observers)
    case active
    /// Only refetch inactive queries (without observers)
    case inactive
    /// Refetch all queries
    case all
}

// MARK: - Environment Key

private struct QueryClientKey: EnvironmentKey {
    static let defaultValue: QueryClient? = nil
}

extension EnvironmentValues {
    /// The query client for this environment
    public var queryClient: QueryClient? {
        get { self[QueryClientKey.self] }
        set { self[QueryClientKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Provide a query client to the view hierarchy
    /// - Parameter queryClient: The query client to provide
    public func queryClient(_ queryClient: QueryClient) -> some View {
        environment(\.queryClient, queryClient)
    }
}
