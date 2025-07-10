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
public struct Query<T: Sendable>: DynamicProperty, ViewLifecycleAttachable {
    
    // MARK: - Internal State
    
    @State private var queryState = QueryState<T>()
    @State private var hasAppeared = false
    @State private var hasInitialFetched = false
    @State private var networkCancellable: AnyCancellable?
    @Environment(\.reportError) private var reportError
    
    // MARK: - Configuration
    
    private let key: any QueryKey
    private let fetch: @Sendable () async throws -> T
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
    
    /// Initialize a Query with a key and fetch function
    /// - Parameters:
    ///   - key: Unique identifier for this query
    ///   - fetch: Async function that returns the data
    ///   - placeholderData: Optional function to provide placeholder data
    ///   - initialData: Optional initial data to use before first fetch
    ///   - options: Query configuration options
    public init(
        key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        placeholderData: (@Sendable (T?) -> T?)? = nil,
        initialData: T? = nil,
        options: QueryOptions = .default
    ) {
        self.key = key
        self.fetch = fetch
        self.placeholderData = placeholderData
        self.initialData = initialData
        self.options = options
    }
    
    /// Convenience initializer with string key
    /// - Parameters:
    ///   - stringKey: String-based query key
    ///   - fetch: Async function that returns the data
    ///   - placeholderData: Optional function to provide placeholder data
    ///   - initialData: Optional initial data to use before first fetch
    ///   - options: Query configuration options
    public init(
        _ stringKey: String,
        fetch: @Sendable @escaping () async throws -> T,
        placeholderData: (@Sendable (T?) -> T?)? = nil,
        initialData: T? = nil,
        options: QueryOptions = .default
    ) {
        self.init(
            key: stringKey,
            fetch: fetch,
            placeholderData: placeholderData,
            initialData: initialData,
            options: options
        )
    }
    
    // MARK: - DynamicProperty Implementation
    
    /// SwiftUI calls this method when the view updates
    nonisolated public func update() {
        Task { @MainActor in
            // Perform initial setup and query on first call
            if !hasInitialFetched {
                hasInitialFetched = true
                handleInitialSetup()
                
                // Only execute initial query if refetchOnAppear is .never
                // Otherwise, let the attach lifecycle handle it
                if options.enabled && options.refetchOnAppear == .never {
                    executeQuery(isInitial: queryState.status == .idle)
                }
                
                setupNetworkMonitoring()
            }
        }
    }
    
    // MARK: - Lifecycle Handling
    
    private func handleInitialSetup() {
        // Set initial data if provided and no data exists
        if queryState.status == .idle, let initialData = initialData {
            queryState.setSuccess(data: initialData)
        }
    }
    
    private func setupNetworkMonitoring() {
        // Only set up network monitoring once
        guard networkCancellable == nil else { return }
        
        // Listen for network reconnection notifications
        networkCancellable = NotificationCenter.default.publisher(for: .networkReconnected)
            .sink { _ in
                Task { @MainActor in
                    self.handleNetworkReconnect()
                }
            }
    }
    
    private func handleNetworkReconnect() {
        guard options.enabled else { return }
        if shouldRefetch(trigger: options.refetchOnReconnect) {
            executeQuery(isInitial: false)
        }
    }
    
    // MARK: - Query Execution
    
    private func executeQuery(isInitial: Bool) {
        guard options.enabled else { return }
        
        queryState.setLoading(isInitial: isInitial)
        
        Task {
            await performQuery()
        }
    }
    
    private func performQuery() async {
        do {
            // Perform fetch off the main actor
            let result = try await fetch()
            
            // Update state on main actor (we're already @MainActor isolated)
            queryState.setSuccess(data: result)
            
        } catch {
            // Update state on main actor (we're already @MainActor isolated)
            queryState.setError(error)
            
            // Report error to environment if configured
            if shouldReportError(error) {
                reportError(error)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldRefetch(trigger: RefetchTrigger) -> Bool {
        switch trigger {
        case .never:
            return false
        case .always:
            return true
        case .ifStale:
            return queryState.isStale || queryState.status == .idle
        case .when(let condition):
            return condition()
        }
    }
    
    private func shouldReportError(_ error: Error) -> Bool {
        switch options.reportOnError {
        case .never:
            return false
        case .always:
            return true
        case .when(let condition):
            return condition(error)
        }
    }
}

// MARK: - Query Actions

extension Query {
    /// Manually refetch the query
    public func refetch() {
        executeQuery(isInitial: false)
    }
    
    /// Mark the query data as stale
    public func invalidate() {
        queryState.markStale()
    }
    
    /// Reset the query to its initial state
    public func reset() {
        queryState.reset()
        hasAppeared = false
    }
}

// MARK: - ViewLifecycleAttachable Conformance

extension Query {
    /// Called when the view appears
    public func onAppear() {
        if !hasAppeared {
            hasAppeared = true
            
            // Only refetch on appear if configured to do so
            if options.enabled && shouldRefetch(trigger: options.refetchOnAppear) {
                executeQuery(isInitial: false)
            }
        }
    }
    
    /// Called when the view disappears
    public func onDisappear() {
        // Currently no action needed on disappear
        // In the future, this could cancel in-flight requests or pause intervals
    }
}
