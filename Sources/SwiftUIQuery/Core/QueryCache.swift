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
    private var queries: [String: WeakQueryInstance] = [:]
    
    // MARK: - Query Management
    
    /// Get or create a query instance
    func getOrCreateQuery<T: Sendable>(
        key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        options: QueryOptions
    ) -> QueryInstance<T> {
        let hashKey = key.hashKey
        
        // Clean up nil weak references
        cleanupNilReferences()
        
        // Check if query already exists
        if let weakQuery = queries[hashKey],
           let existingQuery = weakQuery.instance as? QueryInstance<T> {
            return existingQuery
        }
        
        // Create new query
        let query = QueryInstance<T>(
            key: key,
            fetch: fetch,
            options: options,
            cache: self
        )
        
        // Store weak reference in cache
        queries[hashKey] = WeakQueryInstance(query)
        
        return query
    }
    
    /// Remove a query from the cache
    func removeQuery(key: any QueryKey) {
        let hashKey = key.hashKey
        queries.removeValue(forKey: hashKey)
    }
    
    /// Clean up nil weak references
    private func cleanupNilReferences() {
        queries = queries.compactMapValues { weakQuery in
            weakQuery.instance != nil ? weakQuery : nil
        }
    }
    
    /// Find all queries matching a filter
    func findAll(filter: QueryFilter?) -> [AnyQueryInstance] {
        // Clean up nil references first
        cleanupNilReferences()
        
        let validQueries = queries.compactMap { (_, weakQuery) -> AnyQueryInstance? in
            guard weakQuery.instance != nil else { return nil }
            return weakQuery.anyQuery
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
        
        if let weakQuery = queries[hashKey],
           let typedQuery = weakQuery.instance as? QueryInstance<T> {
            typedQuery.setData(updater: updater)
        }
    }
    
    /// Get query data
    func getQueryData<T: Sendable>(key: any QueryKey) -> T? {
        let hashKey = key.hashKey
        
        if let weakQuery = queries[hashKey],
           let typedQuery = weakQuery.instance as? QueryInstance<T> {
            return typedQuery.getData()
        }
        
        return nil
    }
}

// MARK: - Type Erasure

/// Weak reference wrapper for query instances
@MainActor
struct WeakQueryInstance {
    let anyQuery: AnyQueryInstance
    weak var instance: AnyObject?
    
    init<T: Sendable>(_ query: QueryInstance<T>) {
        self.anyQuery = AnyQueryInstance(query, key: query.key)
        self.instance = query
    }
}

/// Type-erased wrapper for query instances
@MainActor
struct AnyQueryInstance {
    let instance: Any
    let key: any QueryKey
    let invalidate: @MainActor () -> Void
    let fetch: @MainActor () async -> Void
    let reset: @MainActor () -> Void
    let isActive: @MainActor () -> Bool
    
    init<T: Sendable>(_ query: QueryInstance<T>, key: any QueryKey) {
        self.instance = query
        self.key = key
        self.invalidate = { query.invalidate() }
        self.fetch = { await query.fetch() }
        self.reset = { query.reset() }
        self.isActive = { query.isActive }
    }
}