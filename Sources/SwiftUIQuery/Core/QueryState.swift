//
//  QueryState.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUI

// MARK: - Duration Extension

extension Duration {
    /// Convert Duration to TimeInterval (seconds)
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1_000_000_000_000_000_000
    }
}

// MARK: - QueryState

/// The state container for a query, holding all status information and data.
/// Uses @Observable for SwiftUI integration and automatic UI updates.
@Observable
@MainActor
public final class QueryState<T: Sendable> {
    // MARK: - Core State Properties

    /// The current status of the query
    public var status: QueryStatus = .pending

    /// The current fetch status of the query
    public var fetchStatus: FetchStatus = .idle

    /// The data returned by the query (nil if no data or error)
    public var data: T?

    /// The error from the last failed query attempt
    public var error: Error?

    /// The stale time duration for this query
    var staleTime: Duration = .zero

    /// Whether the query has been explicitly invalidated
    public var isInvalidated = false

    // MARK: - Timestamps

    /// When the data was last successfully updated
    public var dataUpdatedAt: Date?

    /// When an error last occurred
    public var errorUpdatedAt: Date?

    /// When the query was last fetched (successful or not)
    public var lastFetchedAt: Date?

    /// Whether the query has been fetched at least once
    public private(set) var isFetched = false

    // MARK: - Computed Properties

    /// Whether the query is pending (no cached data and not finished yet)
    public var isPending: Bool {
        status == .pending
    }

    /// Whether the query is in loading state (actively fetching with no cached data)
    public var isLoading: Bool {
        isPending && fetchStatus == .fetching
    }

    /// Whether the query is currently fetching (includes initial and background refetches)
    public var isFetching: Bool {
        fetchStatus == .fetching
    }

    /// Whether the query is background refetching (excludes initial fetch)
    public var isRefetching: Bool {
        isFetching && !isPending
    }

    /// Whether the query completed successfully
    public var isSuccess: Bool {
        status == .success
    }

    /// Whether the query failed with an error
    public var isError: Bool {
        status == .error
    }

    /// Whether there is any data available (even if stale)
    public var hasData: Bool {
        data != nil
    }

    /// Whether the data is considered stale and should be refetched
    public var isStale: Bool {
        // If invalidated, always stale
        if isInvalidated { return true }

        // No data is always stale
        guard let dataUpdatedAt else { return true }

        // If staleTime is zero, data is always stale
        guard staleTime > .zero else { return true }

        // Check if data has exceeded stale time
        let timeElapsed = Date().timeIntervalSince(dataUpdatedAt)
        return timeElapsed > staleTime.timeInterval
    }

    // MARK: - Initialization

    public init() {}

    public init(data: T) {
        self.data = data
        self.status = .success
        self.dataUpdatedAt = Date()
    }

    // MARK: - State Mutations

    /// Start initial fetch - sets pending status and begins fetching
    public func startInitialFetch() {
        status = .pending
        fetchStatus = .fetching
        error = nil
    }

    /// Start refetch - begins fetching while keeping current status
    public func startRefetch() {
        fetchStatus = .fetching
        // Keep existing status, data, error, etc.
    }

    /// Mark the query as successful with data
    public func setSuccess(data: T) {
        self.data = data
        self.status = .success
        self.error = nil
        self.fetchStatus = .idle
        self.isInvalidated = false // Clear invalidation on successful fetch
        self.isFetched = true
        self.dataUpdatedAt = Date()
        self.lastFetchedAt = Date()
    }

    /// Mark the query as failed with an error
    public func setError(_ error: Error) {
        self.error = error
        self.status = .error
        self.fetchStatus = .idle
        self.isFetched = true
        self.errorUpdatedAt = Date()
        self.lastFetchedAt = Date()
    }

    /// Mark data as stale by clearing the dataUpdatedAt timestamp
    public func markStale() {
        dataUpdatedAt = nil
    }

    /// Mark the query as invalidated
    public func markInvalidated() {
        isInvalidated = true
    }

    /// Reset the query to pending state
    public func reset() {
        status = .pending
        fetchStatus = .idle
        data = nil
        error = nil
        isInvalidated = false
        isFetched = false
        dataUpdatedAt = nil
        errorUpdatedAt = nil
        lastFetchedAt = nil
    }
}

// MARK: - QueryResult

/// A result type that wraps QueryState for easier pattern matching in SwiftUI views.
public enum QueryResult<T: Sendable> {
    case loading
    case success(T)
    case error(Error)

    /// The underlying data if available
    public var data: T? {
        switch self {
        case let .success(data):
            return data
        default:
            return nil
        }
    }

    /// Whether the result represents a loading state
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// Whether the result represents a success state
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// Whether the result represents an error state
    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    /// The error if the result is in error state
    public var error: Error? {
        switch self {
        case let .error(error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - QueryState + QueryResult

extension QueryState {
    /// Convert the current state to a QueryResult for pattern matching
    public var result: QueryResult<T> {
        switch status {
        case .pending:
            return .loading
        case .success:
            guard let data else { return .loading }
            return .success(data)
        case .error:
            guard let error else { return .loading }
            return .error(error)
        }
    }
}
