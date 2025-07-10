//
//  QueryState.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUI

// MARK: - QueryState

/// The state container for a query, holding all status information and data.
/// Uses @Observable for SwiftUI integration and automatic UI updates.
@Observable
public final class QueryState<T: Sendable> {
    
    // MARK: - Core State Properties
    
    /// The current status of the query
    public var status: QueryStatus = .idle
    
    /// The data returned by the query (nil if no data or error)
    public var data: T?
    
    /// The error from the last failed query attempt
    public var error: Error?
    
    /// Whether the query is currently fetching (includes background refetches)
    public var isFetching: Bool = false
    
    /// Whether this is the initial fetch for this query
    public var isInitialLoading: Bool = false
    
    /// Whether the data is considered stale and should be refetched
    public var isStale: Bool = true
    
    // MARK: - Timestamps
    
    /// When the data was last successfully updated
    public var dataUpdatedAt: Date?
    
    /// When an error last occurred
    public var errorUpdatedAt: Date?
    
    /// When the query was last fetched (successful or not)
    public var lastFetchedAt: Date?
    
    // MARK: - Computed Properties
    
    /// Whether the query is in loading state (initial load only)
    public var isLoading: Bool {
        status == .loading && isInitialLoading
    }
    
    /// Whether the query completed successfully
    public var isSuccess: Bool {
        status == .success
    }
    
    /// Whether the query failed with an error
    public var isError: Bool {
        status == .error
    }
    
    /// Whether the query is idle (not yet executed)
    public var isIdle: Bool {
        status == .idle
    }
    
    /// Whether there is any data available (even if stale)
    public var hasData: Bool {
        data != nil
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(data: T) {
        self.data = data
        self.status = .success
        self.dataUpdatedAt = Date()
        self.isStale = false
    }
    
    // MARK: - State Mutations
    
    /// Mark the query as loading
    public func setLoading(isInitial: Bool = false) {
        status = .loading
        isFetching = true
        isInitialLoading = isInitial
        error = nil
    }
    
    /// Mark the query as successful with data
    public func setSuccess(data: T) {
        self.data = data
        self.status = .success
        self.error = nil
        self.isFetching = false
        self.isInitialLoading = false
        self.isStale = false
        self.dataUpdatedAt = Date()
        self.lastFetchedAt = Date()
    }
    
    /// Mark the query as failed with an error
    public func setError(_ error: Error) {
        self.error = error
        self.status = .error
        self.isFetching = false
        self.isInitialLoading = false
        self.errorUpdatedAt = Date()
        self.lastFetchedAt = Date()
    }
    
    /// Mark data as stale
    public func markStale() {
        isStale = true
    }
    
    /// Reset the query to idle state
    public func reset() {
        status = .idle
        data = nil
        error = nil
        isFetching = false
        isInitialLoading = false
        isStale = true
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
        case .success(let data):
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
        case .error(let error):
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
        case .idle, .loading:
            return .loading
        case .success:
            guard let data = data else { return .loading }
            return .success(data)
        case .error:
            guard let error = error else { return .loading }
            return .error(error)
        }
    }
}