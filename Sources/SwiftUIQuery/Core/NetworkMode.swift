import Foundation

// MARK: - Network Mode

/// Configuration for network behavior
/// Equivalent to TanStack Query's NetworkMode
public enum NetworkMode: String, Sendable, Codable {
    /// Only fetch when online (default)
    case online
    /// Fetch regardless of network status
    case always
    /// Pause when offline, resume when online
    case offlineFirst
}
