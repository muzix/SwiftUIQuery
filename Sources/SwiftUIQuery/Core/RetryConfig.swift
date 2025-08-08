import Foundation

// MARK: - Retry Configuration

/// Function signature for custom retry logic
public typealias ShouldRetryFunction = @Sendable (Int, Error) -> Bool

/// Function signature for custom retry delay
public typealias RetryDelayFunction = @Sendable (Int, Error) -> TimeInterval

/// Configuration for retry behavior
/// Equivalent to TanStack Query's RetryValue and RetryDelayValue
public struct RetryConfig: Sendable, Codable {
    /// Whether to retry, how many times, or custom logic
    public let retryAttempts: RetryAttempts
    /// Delay between retries
    public let retryDelay: RetryDelay
    /// Custom retry function (not Codable, handled separately)
    public let customRetryFunction: ShouldRetryFunction?
    /// Custom delay function (not Codable, handled separately)
    public let customDelayFunction: RetryDelayFunction?

    public init(
        retryAttempts: RetryAttempts = .count(3),
        retryDelay: RetryDelay = .exponentialBackoff,
        customRetryFunction: ShouldRetryFunction? = nil,
        customDelayFunction: RetryDelayFunction? = nil
    ) {
        self.retryAttempts = retryAttempts
        self.retryDelay = retryDelay
        self.customRetryFunction = customRetryFunction
        self.customDelayFunction = customDelayFunction
    }

    // MARK: - Codable Conformance

    enum CodingKeys: String, CodingKey {
        case retryAttempts, retryDelay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.retryAttempts = try container.decode(RetryAttempts.self, forKey: .retryAttempts)
        self.retryDelay = try container.decode(RetryDelay.self, forKey: .retryDelay)
        self.customRetryFunction = nil
        self.customDelayFunction = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(retryAttempts, forKey: .retryAttempts)
        try container.encode(retryDelay, forKey: .retryDelay)
        // Note: Custom functions are not encoded
    }

    public enum RetryAttempts: Sendable, Codable {
        case never
        case count(Int)
        case infinite
        // Note: Custom functions cannot be Codable, handled separately
    }

    public enum RetryDelay: Sendable, Codable {
        case fixed(TimeInterval)
        case exponentialBackoff
        // Note: Custom functions cannot be Codable, handled separately
    }

    /// Determine if query should be retried based on failure count and error type
    public func shouldRetry(failureCount: Int, error: Error) -> Bool {
        // If custom retry function is provided, use it exclusively
        if let customRetryFunction {
            return customRetryFunction(failureCount, error)
        }

        // Default retry logic: check retry limits first
        let withinRetryLimit: Bool = switch retryAttempts {
        case .never:
            false
        case let .count(max):
            failureCount < max
        case .infinite:
            true
        }

        // Only retry if we're within limits AND the error is retryable
        guard withinRetryLimit else { return false }

        // Check if the error type should be retried
        if let queryError = error as? QueryError {
            return queryError.isRetryable
        }

        // For non-QueryError types, apply basic heuristics
        if let urlError = error as? URLError {
            switch urlError.code {
            // Network connectivity issues are retryable
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut:
                return true
            // DNS and server issues are retryable
            case .cannotFindHost, .serverCertificateUntrusted:
                return true
            // Client errors are generally not retryable
            case .badURL, .unsupportedURL, .cancelled:
                return false
            default:
                return true // Unknown URLError codes are retryable
            }
        }

        // DecodingError is not retryable - indicates API change or bug
        if error is DecodingError {
            return false
        }

        // Unknown error types are retryable by default (conservative approach)
        return true
    }

    /// Calculate delay for the given failure count
    public func delayForAttempt(failureCount: Int, error: Error) -> TimeInterval {
        // If custom delay function is provided, use it exclusively
        if let customDelayFunction {
            return customDelayFunction(failureCount, error)
        }

        // Default delay logic
        switch retryDelay {
        case let .fixed(delay):
            return delay
        case .exponentialBackoff:
            // Match TanStack Query's exponential backoff: Math.min(1000 * 2 ** failureCount, 30000)
            return min(1.0 * pow(2.0, Double(failureCount)), 30.0)
        }
    }

    // MARK: - Convenience Initializers

    /// Never retry queries - fail immediately on any error
    public static let never = Self(retryAttempts: .never)

    /// Retry indefinitely with exponential backoff (use with caution)
    public static let infinite = Self(retryAttempts: .infinite)

    /// Custom retry function (TanStack Query style)
    /// - Parameter retryFunction: Function that takes (failureCount, error) and returns Bool
    public static func custom(_ retryFunction: @escaping ShouldRetryFunction) -> Self {
        Self(customRetryFunction: retryFunction)
    }

    /// Custom retry with both retry logic and delay logic
    /// - Parameters:
    ///   - retryFunction: Function that determines if retry should happen
    ///   - delayFunction: Function that determines retry delay
    public static func custom(
        retry retryFunction: @escaping ShouldRetryFunction,
        delay delayFunction: @escaping RetryDelayFunction
    ) -> Self {
        Self(customRetryFunction: retryFunction, customDelayFunction: delayFunction)
    }
}
