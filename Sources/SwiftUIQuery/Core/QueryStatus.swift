import Foundation

// MARK: - Query Status & Fetch Status

/// Represents the overall state of query data
/// Equivalent to TanStack Query's QueryStatus
public enum QueryStatus: String, Sendable, Codable {
    /// No cached data, query hasn't completed successfully yet
    case pending
    /// Query attempt resulted in an error
    case error
    /// Query has received a response with no errors
    case success
}

/// Represents the fetching activity state
/// Equivalent to TanStack Query's FetchStatus
public enum FetchStatus: String, Sendable, Codable {
    /// QueryFn is executing (initial load or background refetch)
    case fetching
    /// Query wanted to fetch but has been paused
    case paused
    /// Query is not fetching
    case idle
}
