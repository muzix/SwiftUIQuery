import Foundation

// MARK: - Refetch Configuration

/// Configuration for when to refetch queries in iOS/SwiftUI
/// iOS-specific equivalent to TanStack Query's refetch triggers
public struct RefetchTriggers: Sendable, Codable, Equatable {
    /// Refetch when view appears (SwiftUI .onAppear)
    public let onAppear: Bool
    /// Refetch when app becomes active from background
    public let onAppForeground: Bool
    /// Refetch when network connectivity is restored
    public let onNetworkReconnect: Bool

    public init(onAppear: Bool = true, onAppForeground: Bool = true, onNetworkReconnect: Bool = true) {
        self.onAppear = onAppear
        self.onAppForeground = onAppForeground
        self.onNetworkReconnect = onNetworkReconnect
    }

    public static let `default` = Self()
    public static let never = Self(onAppear: false, onAppForeground: false, onNetworkReconnect: false)
}

/// Enum specifying when to refetch on view appear
/// Maps to SwiftUI .onAppear behavior
public enum RefetchOnAppear: Sendable, Codable, Equatable {
    /// Always refetch when view appears
    case always
    /// Only refetch if data is stale when view appears
    case ifStale
    /// Never automatically refetch on view appear
    case never
}
