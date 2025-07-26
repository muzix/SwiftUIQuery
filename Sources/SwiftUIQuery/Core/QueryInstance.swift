//
//  QueryInstance.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation

/// Represents a single query instance in the cache
@MainActor
final class QueryInstance<T: Sendable>: Sendable {
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

    /// Error reporting function from environment
    private var reportError: (@MainActor @Sendable (Error) -> Void)?

    // MARK: - Initialization

    init(
        key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        options: QueryOptions,
        cache: QueryCache,
        reportError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        self.key = key
        self.fetchFn = fetch
        self.options = options
        self.cache = cache
        self.reportError = reportError
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

    /// Fetch data for this query
    func fetch() async {
        // Cancel any existing fetch
        fetchTask?.cancel()

        // Don't fetch if disabled
        guard options.enabled else { return }

        // Update fetch status - different behavior for initial vs refetch
        if state.isFetched {
            // Background refetch - keep current status, just start fetching
            state.startRefetch()
        } else {
            // Initial fetch - set to pending and start fetching
            state.startInitialFetch()
        }

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

                // Always update the query state first
                state.setError(error)

                // Then check if error should also be reported to error boundary
                let shouldReport = shouldReportError(error)

                if shouldReport, let reportError {
                    // Report to error boundary (in addition to state update)
                    reportError(error)
                }
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

    /// Determine if error should be reported to error boundary based on options
    private func shouldReportError(_ error: Error) -> Bool {
        switch options.reportOnError {
        case .never:
            return false
        case .always:
            return true
        case let .when(condition):
            return condition(error)
        }
    }

    /// Update the error reporting function (called when Query updates)
    func updateReportError(_ reportError: (@MainActor @Sendable (Error) -> Void)?) {
        self.reportError = reportError
    }

    deinit {
        // Cancel any in-flight requests when deallocated
        fetchTask?.cancel()
    }
}
