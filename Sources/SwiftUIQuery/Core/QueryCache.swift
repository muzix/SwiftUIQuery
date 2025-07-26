//
//  QueryCache.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation

/// Cache that manages all query instances
@MainActor
final class QueryCache {
    
    // MARK: - Properties
    
    /// All cached queries, keyed by their hash (weak references)
    private var queries: [String: AnyQueryInstance] = [:]
    
    // MARK: - Query Management
    
    /// Get or create a query instance
    func getOrCreateQuery<T: Sendable>(
        key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        options: QueryOptions,
        reportError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) -> QueryInstance<T> {
        let hashKey = key.hashKey
        
        // Clean up nil weak references
        cleanupNilReferences()
        
        // Check if query already exists
        if let anyQuery = queries[hashKey],
           let existingQuery = anyQuery.instance as? QueryInstance<T> {
            // Update the report error function for existing query
            existingQuery.updateReportError(reportError)
            return existingQuery
        }
        
        // Create new query
        let query = QueryInstance<T>(
            key: key,
            fetch: fetch,
            options: options,
            cache: self,
            reportError: reportError
        )
        
        // Store AnyQueryInstance in cache
        queries[hashKey] = AnyQueryInstance(query, key: key)
        
        return query
    }
    
    /// Remove a query from the cache
    func removeQuery(key: any QueryKey) {
        let hashKey = key.hashKey
        queries.removeValue(forKey: hashKey)
    }
    
    /// Clean up nil weak references
    private func cleanupNilReferences() {
        queries = queries.compactMapValues { anyQuery in
            anyQuery.instance != nil ? anyQuery : nil
        }
    }
    
    /// Find all queries matching a filter
    func findAll(filter: QueryFilter?) -> [AnyQueryInstance] {
        // Clean up nil references first
        cleanupNilReferences()
        
        let validQueries = queries.compactMap { (_, anyQuery) -> AnyQueryInstance? in
            return anyQuery.instance != nil ? anyQuery : nil
        }
        
        guard let filter = filter else {
            // Return all queries if no filter
            return validQueries
        }
        
        return validQueries.filter { query in
            // Match by exact key
            if let filterKey = filter.key {
                return query.key.hashKey == filterKey.hashKey
            }
            
            // Match by predicate
            if let predicate = filter.predicate {
                return predicate(query.key)
            }
            
            return true
        }
    }
    
    /// Remove queries matching a filter
    func removeQueries(filter: QueryFilter?) {
        let queriesToRemove = findAll(filter: filter)
        
        for query in queriesToRemove {
            queries.removeValue(forKey: query.key.hashKey)
        }
    }
    
    /// Clear all queries
    func clear() {
        queries.removeAll()
    }
    
    /// Set query data directly
    func setQueryData<T: Sendable>(key: any QueryKey, updater: @Sendable (T?) -> T?) {
        let hashKey = key.hashKey
        
        if let anyQuery = queries[hashKey],
           let typedQuery = anyQuery.instance as? QueryInstance<T> {
            typedQuery.setData(updater: updater)
        }
    }
    
    /// Get query data
    func getQueryData<T: Sendable>(key: any QueryKey) -> T? {
        let hashKey = key.hashKey
        
        if let anyQuery = queries[hashKey],
           let typedQuery = anyQuery.instance as? QueryInstance<T> {
            return typedQuery.getData()
        }
        
        return nil
    }
}

// MARK: - Type Erasure

/// Type-erased wrapper for query instances
@MainActor
public class AnyQueryInstance {
    weak var instance: AnyObject?
    public let key: any QueryKey
    public let invalidate: @MainActor () -> Void
    public let fetch: @MainActor () async -> Void
    public let reset: @MainActor () -> Void
    public let isActive: @MainActor () -> Bool
    public let getStatus: @MainActor () -> QueryStatus
    public let isStale: @MainActor () -> Bool
    public let isFetching: @MainActor () -> Bool
    public let dataUpdatedAt: @MainActor () -> Date?
    public let hasData: @MainActor () -> Bool
    
    init<T: Sendable>(_ query: QueryInstance<T>, key: any QueryKey) {
        self.instance = query
        self.key = key
        self.invalidate = { [weak query] in query?.invalidate() }
        self.fetch = { [weak query] in await query?.fetch() }
        self.reset = { [weak query] in query?.reset() }
        self.isActive = { [weak query] in query?.isActive ?? false }
        self.getStatus = { [weak query] in query?.state.status ?? .pending }
        self.isStale = { [weak query] in query?.state.isStale ?? false }
        self.isFetching = { [weak query] in query?.state.isFetching ?? false }
        self.dataUpdatedAt = { [weak query] in query?.state.dataUpdatedAt }
        self.hasData = { [weak query] in query?.state.data != nil }
    }
}
