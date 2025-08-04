import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("Retry Logic Tests")
@MainActor
struct RetryLogicTests {
    // MARK: - QueryError.isRetryable Tests

    @Test("Network errors are retryable")
    func networkErrorsAreRetryable() {
        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))
        #expect(networkError.isRetryable == true)

        let timeoutError = QueryError.timeout
        #expect(timeoutError.isRetryable == true)
    }

    @Test("Client errors are not retryable")
    func clientErrorsAreNotRetryable() {
        let notFoundError = QueryError.notFound()
        #expect(notFoundError.isRetryable == false)

        let clientError = QueryError.clientError(statusCode: 400)
        #expect(clientError.isRetryable == false)

        let httpClientError = QueryError.httpError(statusCode: 404)
        #expect(httpClientError.isRetryable == false)
    }

    @Test("Server errors are retryable")
    func serverErrorsAreRetryable() {
        let serverError = QueryError.serverError()
        #expect(serverError.isRetryable == true)

        let http500Error = QueryError.httpError(statusCode: 500)
        #expect(http500Error.isRetryable == true)

        let http502Error = QueryError.httpError(statusCode: 502)
        #expect(http502Error.isRetryable == true)
    }

    @Test("Decoding errors are not retryable")
    func decodingErrorsAreNotRetryable() {
        let decodingError = QueryError.decodingError(DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "Invalid JSON"
        )))
        #expect(decodingError.isRetryable == false)
    }

    @Test("Cancelled errors are not retryable")
    func cancelledErrorsAreNotRetryable() {
        let cancelledError = QueryError.cancelled
        #expect(cancelledError.isRetryable == false)
    }

    @Test("Configuration errors are not retryable")
    func configurationErrorsAreNotRetryable() {
        let configError = QueryError.invalidConfiguration("Invalid setup")
        #expect(configError.isRetryable == false)
    }

    // MARK: - RetryConfig.shouldRetry Tests

    @Test("RetryConfig respects error retryability")
    func retryConfigRespectsErrorRetryability() {
        let config = RetryConfig() // Default: retry 3 times

        // Network error should be retried
        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))
        #expect(config.shouldRetry(failureCount: 0, error: networkError) == true)
        #expect(config.shouldRetry(failureCount: 2, error: networkError) == true)
        #expect(config.shouldRetry(failureCount: 3, error: networkError) == false) // Exceeds limit

        // Decoding error should not be retried
        let decodingError = QueryError.decodingError(DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "Invalid JSON"
        )))
        #expect(config.shouldRetry(failureCount: 0, error: decodingError) == false)
        #expect(config.shouldRetry(failureCount: 1, error: decodingError) == false)

        // 404 error should not be retried
        let notFoundError = QueryError.notFound()
        #expect(config.shouldRetry(failureCount: 0, error: notFoundError) == false)
    }

    @Test("RetryConfig handles URLError types correctly")
    func retryConfigHandlesURLErrorTypes() {
        let config = RetryConfig(retryAttempts: .count(2))

        // Network connectivity issues are retryable
        let networkLostError = URLError(.networkConnectionLost)
        #expect(config.shouldRetry(failureCount: 0, error: networkLostError) == true)
        #expect(config.shouldRetry(failureCount: 1, error: networkLostError) == true)
        #expect(config.shouldRetry(failureCount: 2, error: networkLostError) == false)

        let notConnectedError = URLError(.notConnectedToInternet)
        #expect(config.shouldRetry(failureCount: 0, error: notConnectedError) == true)

        let timedOutError = URLError(.timedOut)
        #expect(config.shouldRetry(failureCount: 0, error: timedOutError) == true)

        // Client errors are not retryable
        let badURLError = URLError(.badURL)
        #expect(config.shouldRetry(failureCount: 0, error: badURLError) == false)

        let cancelledURLError = URLError(.cancelled)
        #expect(config.shouldRetry(failureCount: 0, error: cancelledURLError) == false)
    }

    @Test("RetryConfig handles DecodingError correctly")
    func retryConfigHandlesDecodingError() {
        let config = RetryConfig(retryAttempts: .count(3))

        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSON"))
        #expect(config.shouldRetry(failureCount: 0, error: decodingError) == false)
        #expect(config.shouldRetry(failureCount: 1, error: decodingError) == false)
    }

    @Test("Custom retry function overrides default logic")
    func customRetryFunctionOverridesDefault() {
        // Custom function that only retries network errors once
        let customConfig = RetryConfig.custom { failureCount, error in
            guard failureCount < 1 else { return false }
            return (error as? QueryError)?.isNetworkError == true
        }

        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))
        let notFoundError = QueryError.notFound()

        // Network error should be retried once
        #expect(customConfig.shouldRetry(failureCount: 0, error: networkError) == true)
        #expect(customConfig.shouldRetry(failureCount: 1, error: networkError) == false)

        // Not found error should not be retried (even though default count would allow it)
        #expect(customConfig.shouldRetry(failureCount: 0, error: notFoundError) == false)
    }

    @Test("Never retry config works correctly")
    func neverRetryConfigWorks() {
        let neverConfig = RetryConfig.never

        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))
        let serverError = QueryError.serverError()

        // Even retryable errors should not be retried
        #expect(neverConfig.shouldRetry(failureCount: 0, error: networkError) == false)
        #expect(neverConfig.shouldRetry(failureCount: 0, error: serverError) == false)
    }

    @Test("Infinite retry config respects error retryability")
    func infiniteRetryConfigRespectsErrorRetryability() {
        let infiniteConfig = RetryConfig.infinite

        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))
        let notFoundError = QueryError.notFound()

        // Retryable errors should be retried infinitely
        #expect(infiniteConfig.shouldRetry(failureCount: 10, error: networkError) == true)
        #expect(infiniteConfig.shouldRetry(failureCount: 100, error: networkError) == true)

        // Non-retryable errors should not be retried even with infinite config
        #expect(infiniteConfig.shouldRetry(failureCount: 0, error: notFoundError) == false)
        #expect(infiniteConfig.shouldRetry(failureCount: 1, error: notFoundError) == false)
    }

    // MARK: - Delay Function Tests

    @Test("Custom delay function is used when provided")
    func customDelayFunctionIsUsed() {
        // Custom delay function that returns fixed 5 seconds regardless of failure count
        let customConfig = RetryConfig.custom(
            retry: { _, _ in true },
            delay: { _, _ in 5.0 }
        )

        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))

        #expect(customConfig.delayForAttempt(failureCount: 0, error: networkError) == 5.0)
        #expect(customConfig.delayForAttempt(failureCount: 3, error: networkError) == 5.0)
        #expect(customConfig.delayForAttempt(failureCount: 10, error: networkError) == 5.0)
    }

    @Test("Default exponential backoff works correctly")
    func defaultExponentialBackoffWorks() {
        let config = RetryConfig(retryDelay: .exponentialBackoff)
        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))

        // Test exponential backoff: min(1.0 * 2^failureCount, 30.0)
        #expect(config.delayForAttempt(failureCount: 0, error: networkError) == 1.0) // 2^0 = 1
        #expect(config.delayForAttempt(failureCount: 1, error: networkError) == 2.0) // 2^1 = 2
        #expect(config.delayForAttempt(failureCount: 2, error: networkError) == 4.0) // 2^2 = 4
        #expect(config.delayForAttempt(failureCount: 3, error: networkError) == 8.0) // 2^3 = 8
        #expect(config.delayForAttempt(failureCount: 10, error: networkError) == 30.0) // Capped at 30
    }

    @Test("Fixed delay works correctly")
    func fixedDelayWorks() {
        let config = RetryConfig(retryDelay: .fixed(2.5))
        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))

        #expect(config.delayForAttempt(failureCount: 0, error: networkError) == 2.5)
        #expect(config.delayForAttempt(failureCount: 5, error: networkError) == 2.5)
        #expect(config.delayForAttempt(failureCount: 100, error: networkError) == 2.5)
    }
}
