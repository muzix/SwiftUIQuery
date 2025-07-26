//
//  FetchProtocol.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation

// MARK: - FetchProtocol

/// Protocol for objects that can fetch data for queries
/// This allows for dynamic input and stateful fetch logic
@MainActor
public protocol FetchProtocol: AnyObject, Sendable {
    associatedtype Output: Sendable

    /// Fetch data asynchronously
    /// This method is called each time the query needs to fetch data
    /// and can access current state/properties of the conforming object
    func fetch() async throws -> Output
}

// MARK: - Type Erasure for FetchProtocol

/// Type-erased wrapper for FetchProtocol objects
@MainActor
public struct AnyFetcher<T: Sendable>: @unchecked Sendable {
    private let _fetch: @Sendable () async throws -> T

    /// Initialize with a FetchProtocol conforming object
    public init<F: FetchProtocol>(_ fetcher: F) where F.Output == T {
        self._fetch = { @MainActor in
            try await fetcher.fetch()
        }
    }

    /// Initialize with a closure (for backward compatibility)
    public init(_ fetch: @Sendable @escaping () async throws -> T) {
        self._fetch = fetch
    }

    /// Execute the fetch
    public func fetch() async throws -> T {
        try await _fetch()
    }
}

// MARK: - Default Closure Fetcher

/// Default fetcher implementation that wraps a closure for backward compatibility
@MainActor
public final class Fetcher<T: Sendable>: ObservableObject, FetchProtocol {
    private let fetchClosure: @Sendable () async throws -> T

    public init(fetch: @Sendable @escaping () async throws -> T) {
        self.fetchClosure = fetch
    }

    public func fetch() async throws -> T {
        try await fetchClosure()
    }
}
