//
//  QueryTypes.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUI

// MARK: - QueryKey Protocol

/// A protocol that defines a query key used to uniquely identify queries.
/// Query keys determine when queries should be refetched and enable cache management.
public protocol QueryKey: Hashable, Sendable {
    /// A string representation of the query key for debugging and logging
    var stringValue: String { get }
}

// MARK: - QueryKey Extensions

extension String: QueryKey {
    public var stringValue: String { self }
}

extension Array: QueryKey where Element: QueryKey {
    public var stringValue: String {
        "[" + map(\.stringValue).joined(separator: ", ") + "]"
    }
}

// MARK: - QueryStatus Enum

/// Represents the current status of a query execution.
public enum QueryStatus: Sendable, Equatable {
    /// Query has not been executed yet
    case idle
    /// Query is currently being executed
    case loading
    /// Query completed successfully with data
    case success
    /// Query failed with an error
    case error
}

// MARK: - RefetchTrigger Enum

/// Defines when a query should be automatically refetched.
public enum RefetchTrigger: Sendable, Equatable {
    /// Never automatically refetch
    case never
    /// Always refetch when conditions are met
    case always
    /// Only refetch if data is stale
    case ifStale
    /// Refetch based on a custom condition
    case when(@Sendable () -> Bool)
    
    public static func == (lhs: RefetchTrigger, rhs: RefetchTrigger) -> Bool {
        switch (lhs, rhs) {
        case (.never, .never), (.always, .always), (.ifStale, .ifStale):
            return true
        case (.when, .when):
            return false // Function equality is not deterministic
        default:
            return false
        }
    }
}

// MARK: - ThrowOnError Enum

/// Defines when query errors should be thrown vs handled in state.
public enum ThrowOnError: Sendable, Equatable {
    /// Never throw errors, always handle in state
    case never
    /// Always throw errors
    case always
    /// Throw errors based on a custom condition
    case when(@Sendable (Error) -> Bool)
    
    public static func == (lhs: ThrowOnError, rhs: ThrowOnError) -> Bool {
        switch (lhs, rhs) {
        case (.never, .never), (.always, .always):
            return true
        case (.when, .when):
            return false // Function equality is not deterministic
        default:
            return false
        }
    }
}

// MARK: - NetworkMode Enum

/// Defines how queries should behave based on network connectivity.
public enum NetworkMode: Sendable, Equatable {
    /// Only execute queries when online
    case online
    /// Always execute queries regardless of network state
    case always
    /// Return cached data when offline, fetch when online
    case offlineFirst
}