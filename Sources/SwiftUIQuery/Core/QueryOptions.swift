//
//  QueryOptions.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUI

// MARK: - QueryOptions

/// Configuration options for query behavior, based on the API design specification.
/// Note: select, placeholderData, and initialData are handled as separate Query parameters
public struct QueryOptions: Sendable, Equatable {
    // MARK: - Timing Configuration

    /// How long data is considered fresh before becoming stale
    /// Default: 0 (immediately stale, matching TanStack Query)
    public var staleTime: Duration

    // MARK: - Refetch Triggers

    /// Whether to refetch when the query appears/mounts
    /// Default: .ifStale (matching TanStack Query refetchOnMount)
    public var refetchOnAppear: RefetchTrigger

    /// Whether to refetch when network connection is restored
    /// Default: .ifStale (matching TanStack Query refetchOnReconnect)
    public var refetchOnReconnect: RefetchTrigger

    /// Automatic refetch interval (nil = no automatic refetching)
    /// Default: nil (matching TanStack Query)
    public var refetchInterval: Duration?

    /// Whether refetch interval should continue when app is in background
    /// Default: false (matching TanStack Query)
    public var refetchIntervalInBackground: Bool

    // MARK: - Query Execution

    /// Whether the query should execute automatically
    /// Default: true (matching TanStack Query)
    public var enabled: Bool

    /// Number of retry attempts on failure
    /// Default: 3 (matching TanStack Query)
    public var retry: Int

    /// When to report errors to the environment vs handle them in state
    /// Default: .never (handle in state, matching TanStack Query)
    public var reportOnError: ThrowOnError

    // MARK: - Initialization

    public init(
        staleTime: Duration = .zero,
        refetchOnAppear: RefetchTrigger = .ifStale,
        refetchOnReconnect: RefetchTrigger = .ifStale,
        refetchInterval: Duration? = nil,
        refetchIntervalInBackground: Bool = false,
        enabled: Bool = true,
        retry: Int = 3,
        reportOnError: ThrowOnError = .never
    ) {
        self.staleTime = staleTime
        self.refetchOnAppear = refetchOnAppear
        self.refetchOnReconnect = refetchOnReconnect
        self.refetchInterval = refetchInterval
        self.refetchIntervalInBackground = refetchIntervalInBackground
        self.enabled = enabled
        self.retry = retry
        self.reportOnError = reportOnError
    }
}

// MARK: - Default Options

extension QueryOptions {
    /// Default options that match TanStack Query's important defaults
    public static let `default` = QueryOptions()
}
