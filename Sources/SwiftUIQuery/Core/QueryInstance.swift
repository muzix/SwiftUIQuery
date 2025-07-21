//
//  QueryInstance.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation

/// Represents a single query instance in the cache
@MainActor
final class QueryInstance<T: Sendable>: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The query key
    let key: any QueryKey
    
    /// The fetch function
    private let fetchFn: @Sendable () async throws -> T
    
    /// Query options
    let options: QueryOptions
    
    /// Current state (exposed publicly for SwiftUI observation)
    let state = QueryState<T>()
    
    /// Current fetch task
    private var fetchTask: Task<Void, Never>?
    
    /// Whether this query is currently active (view is visible)
    var isActive = false
    
    /// Reference to the cache (weak to avoid retain cycle)
    private weak var cache: QueryCache?
    
    // MARK: - Initialization
    
    init(
        key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        options: QueryOptions,
        cache: QueryCache
    ) {
        self.key = key
        self.fetchFn = fetch
        self.options = options
        self.cache = cache
        self.state.staleTime = options.staleTime
    }
    
    // MARK: - Active State Management
    
    /// Mark this query as active (view appeared)
    func markActive() {
        isActive = true
    }
    
    /// Mark this query as inactive (view disappeared)
    func markInactive() {
        isActive = false
    }
    
    // MARK: - State Management
    
    /// Get the current state
    func getState() -> QueryState<T> {
        state
    }
    
    /// Get the current data
    func getData() -> T? {
        state.data
    }
    
    /// Set data directly
    func setData(updater: @Sendable (T?) -> T?) {
        if let newData = updater(state.data) {
            state.setSuccess(data: newData)
        }
    }
    
    /// Fetch data for this query
    func fetch() async {
        // Cancel any existing fetch
        fetchTask?.cancel()
        
        // Don't fetch if disabled
        guard options.enabled else { return }
        
        // Update state to loading
        let isInitial = state.status == .idle
        state.setLoading(isInitial: isInitial)
        
        // Create new fetch task
        let task = Task {
            do {
                let result = try await fetchFn()
                
                // Update state on success
                guard !Task.isCancelled else { return }
                state.setSuccess(data: result)
                
            } catch {
                // Update state on error
                guard !Task.isCancelled else { return }
                state.setError(error)
            }
        }
        
        fetchTask = task
        await task.value
    }
    
    /// Invalidate this query
    func invalidate() {
        state.markStale()
        state.markInvalidated()
    }
    
    /// Reset this query to initial state
    func reset() {
        fetchTask?.cancel()
        state.reset()
    }
    
    // MARK: - Private Methods
    
    deinit {
        // Cancel any in-flight requests when deallocated
        fetchTask?.cancel()
    }
}
