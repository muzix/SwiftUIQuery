//
//  Query.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import Combine

// MARK: - Query Property Wrapper

/// A property wrapper for declarative data fetching in SwiftUI, inspired by TanStack Query.
/// Provides automatic caching, background refetching, and state management.
@propertyWrapper @MainActor
public struct Query<F: FetchProtocol>: DynamicProperty, ViewLifecycleAttachable where F.Output: Sendable {
    
    public typealias T = F.Output
    
    // MARK: - Internal State
    
    @State private var queryState = QueryState<T>()
    @State private var queryInstance: QueryInstance<T>?
    @State private var hasSetupQuery = false
    @State private var hasFetchedOnAppear = false
    @Environment(\.queryClient) private var queryClient
    @Environment(\.reportError) private var reportError
    
    // MARK: - Configuration
    
    private let key: any QueryKey
    public let fetcher: F  // Make fetcher public and strongly typed
    private let options: QueryOptions
    
    // Data initialization
    private let placeholderData: (@Sendable (T?) -> T?)?
    private let initialData: T?
    
    // MARK: - Wrapped Value
    
    /// Access to the query state and data
    public var wrappedValue: QueryState<T> {
        queryState
    }
    
    /// Direct access to the query state for advanced usage
    public var projectedValue: QueryState<T> {
        queryState
    }
    
    // MARK: - Initialization
    
    /// Initialize a Query with a key and fetcher object
    /// - Parameters:
    ///   - key: Unique identifier for this query
    ///   - fetcher: Object conforming to FetchProtocol that can fetch data
    ///   - placeholderData: Optional function to provide placeholder data
    ///   - initialData: Optional initial data to use before first fetch
    ///   - options: Query configuration options
    public init(
        _ key: any QueryKey,
        fetcher: F,
        placeholderData: (@Sendable (T?) -> T?)? = nil,
        initialData: T? = nil,
        options: QueryOptions = .default
    ) {
        self.key = key
        self.fetcher = fetcher
        self.placeholderData = placeholderData
        self.initialData = initialData
        self.options = options
    }

    /// Initialize a Query with a key and fetch function (backward compatibility)
    /// - Parameters:
    ///   - key: Unique identifier for this query
    ///   - fetch: Async function that returns the data
    ///   - placeholderData: Optional function to provide placeholder data
    ///   - initialData: Optional initial data to use before first fetch
    ///   - options: Query configuration options
    public init<T: Sendable>(
        _ key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        placeholderData: (@Sendable (T?) -> T?)? = nil,
        initialData: T? = nil,
        options: QueryOptions = .default
    ) where F.Output == T, F == Fetcher<T> {
        self.key = key
        self.fetcher = Fetcher(fetch: fetch)
        self.placeholderData = placeholderData
        self.initialData = initialData
        self.options = options
    }

    // MARK: - DynamicProperty Implementation
    
    /// SwiftUI calls this method when the view updates
    nonisolated public func update() {
        Task { @MainActor in
            // Setup query on first call
            if !hasSetupQuery {
                hasSetupQuery = true
                setupQuery()
            }
        }
    }
    
    // MARK: - Query Setup
    
    private func setupQuery() {
        guard let client = queryClient else {
            print("Warning: QueryClient not found in environment. Make sure to provide it using .queryClient(_:)")
            return
        }
        
        // Create the fetch function from the fetcher
        let fetchFunction: @Sendable () async throws -> T = { @MainActor [weak fetcher] in
            guard let fetcher else { throw CancellationError() }
            return try await fetcher.fetch()
        }
        
        // Get or create query instance from client
        let instance = client.getQuery(
            key: key,
            fetch: fetchFunction,
            options: options,
            reportError: reportError.action
        )
        
        self.queryInstance = instance
        
        // Assign the shared state to our @State property for SwiftUI tracking
        self.queryState = instance.state

        // Always mark query as active when view updates (important for cached queries)
        self.queryInstance?.markActive()

        // Set initial data if provided and state is still pending
        if let initialData = initialData, queryState.status == .pending && !queryState.isFetched {
            queryState.setSuccess(data: initialData)
        }
        
        // Set placeholder data if provided
        if let placeholderData = placeholderData {
            if let data = placeholderData(queryState.data) {
                queryState.data = data
            }
        }
        
        // If we should fetch and haven't fetched on appear yet, fetch immediately
        if queryState.status == .pending && !queryState.isFetched && !hasFetchedOnAppear && shouldFetchOnAppears() {
            hasFetchedOnAppear = true
            Task {
                await instance.fetch()
            }
        }
    }
    
}

// MARK: - Query Actions

extension Query {
    /// Manually refetch the query
    public func refetch() {
        Task {
            await queryInstance?.fetch()
        }
    }
    
    /// Manually refetch the query with fetcher configuration
    /// - Parameter configure: Configuration closure to modify the fetcher before refetching
    public func refetch(configure: @MainActor @escaping (F) -> Void) {
        Task { @MainActor in
            configure(fetcher)
            await queryInstance?.fetch()
        }
    }
    
    /// Mark the query data as stale
    public func invalidate() {
        queryInstance?.invalidate()
    }
    
    /// Reset the query to its initial state
    public func reset() {
        queryInstance?.reset()
    }
}

// MARK: - ViewLifecycleAttachable Conformance

extension Query {
    /// Called when the view appears
    public func onAppear() {
        print("onAppear: \(key.stringValue)")
        guard let instance = queryInstance else { return }
        
        // Mark query as active
        instance.markActive()
        
        // Decide if we should fetch on mount (only if haven't fetched yet)
        if !hasFetchedOnAppear && shouldFetchOnAppears() {
            hasFetchedOnAppear = true
            Task {
                await instance.fetch()
            }
        }
    }
    
    /// Called when the view disappears
    public func onDisappear() {
        print("onDisappear: \(key.stringValue)")
        guard let instance = queryInstance else { return }
        
        // Mark query as inactive
        instance.markInactive()
        
        // If query is in error state, reset it for a clean slate on next appear
        if instance.state.status == .error {
            print("onDisappear: resetting error state for \(key.stringValue)")
            instance.reset()
        }
        
        // Reset the fetch flag so it can fetch again on next appear
        hasFetchedOnAppear = false
    }
    
    // MARK: - Helper Methods
    
    private func shouldFetchOnAppears() -> Bool {
        guard options.enabled else { return false }
        
        switch options.refetchOnAppear {
        case .never:
            return !queryState.isFetched
        case .always:
            return true
        case .ifStale:
            return queryState.isStale || !queryState.isFetched
        case .when(let condition):
            return condition()
        }
    }
}
