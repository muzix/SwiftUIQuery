import Foundation

// MARK: - Query Error Types

/// Standard error type for query operations
public struct QueryError: Error, Sendable, Codable, Equatable {
    public let message: String
    public let code: String?
    public let underlyingError: String?

    public init(message: String, code: String? = nil, underlyingError: Error? = nil) {
        self.message = message
        self.code = code
        self.underlyingError = underlyingError?.localizedDescription
    }

    public var isNetworkError: Bool {
        code == "NETWORK_ERROR"
    }

    /// Determines if this error type should be retried by default
    /// Following common retry patterns used in production systems
    public var isRetryable: Bool {
        guard let code else { return true } // Unknown errors are retryable by default

        switch code {
        // Network-related errors are retryable
        case "NETWORK_ERROR", "TIMEOUT":
            return true

        // Client errors (4xx) are generally not retryable
        case "NOT_FOUND", "CLIENT_ERROR":
            return false

        // Specific client error codes that are not retryable
        case let code where code.hasPrefix("HTTP_4"):
            return false

        // Server errors (5xx) are retryable as they might be temporary
        case "SERVER_ERROR":
            return true

        // Specific server error codes - most are retryable except some
        case let code where code.hasPrefix("HTTP_5"):
            // 501 Not Implemented is permanent, don't retry
            return code != "HTTP_501"

        // Data parsing errors are not retryable (indicates bug or API change)
        case "DECODING_ERROR":
            return false

        // Query was cancelled - not an error condition, don't retry
        case "CANCELLED":
            return false

        // Configuration errors are not retryable
        case "INVALID_CONFIGURATION":
            return false

        // Generic query failures are retryable (unknown cause)
        case "QUERY_FAILED":
            return true

        default:
            return true // Unknown error codes are retryable by default
        }
    }

    // MARK: - Common Error Cases

    /// Network-related error (connectivity issues)
    public static func networkError(_ error: Error) -> Self {
        Self(message: "Network error occurred", code: "NETWORK_ERROR", underlyingError: error)
    }

    /// Resource not found (HTTP 404)
    public static func notFound(_ message: String = "Resource not found") -> Self {
        Self(message: message, code: "NOT_FOUND")
    }

    /// HTTP error with status code
    public static func httpError(statusCode: Int, message: String? = nil) -> Self {
        let defaultMessage = "HTTP error \(statusCode)"
        return Self(message: message ?? defaultMessage, code: "HTTP_\(statusCode)")
    }

    /// Server error (HTTP 5xx)
    public static func serverError(statusCode: Int = 500, message: String? = nil) -> Self {
        let defaultMessage = "Server error \(statusCode)"
        return Self(message: message ?? defaultMessage, code: "SERVER_ERROR")
    }

    /// Client error (HTTP 4xx)
    public static func clientError(statusCode: Int, message: String? = nil) -> Self {
        let defaultMessage = "Client error \(statusCode)"
        return Self(message: message ?? defaultMessage, code: "CLIENT_ERROR")
    }

    /// Data parsing/decoding error
    public static func decodingError(_ error: Error) -> Self {
        Self(message: "Failed to decode response", code: "DECODING_ERROR", underlyingError: error)
    }

    /// Query was cancelled
    public static let cancelled = Self(message: "Query was cancelled", code: "CANCELLED")

    /// Query timeout
    public static let timeout = Self(message: "Query timed out", code: "TIMEOUT")

    /// Invalid query configuration
    public static func invalidConfiguration(_ message: String) -> Self {
        Self(message: message, code: "INVALID_CONFIGURATION")
    }

    /// Generic query failure
    public static func queryFailed(_ error: Error) -> Self {
        Self(message: "Query failed", code: "QUERY_FAILED", underlyingError: error)
    }
}

/// Observer identifier for tracking query observers
public struct QueryObserverIdentifier: Sendable, Hashable, Codable {
    public let id: UUID

    public init() {
        self.id = UUID()
    }
}
