import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("QueryState Tests")
@MainActor
struct QueryStateTests {
    // MARK: - Initialization Tests

    @Test("QueryState default initialization")
    func defaultInitialization() {
        let state = QueryState<String>.defaultState()

        #expect(state.data == nil)
        #expect(state.dataUpdateCount == 0)
        #expect(state.dataUpdatedAt == 0)
        #expect(state.error == nil)
        #expect(state.errorUpdateCount == 0)
        #expect(state.errorUpdatedAt == 0)
        #expect(state.fetchFailureCount == 0)
        #expect(state.fetchFailureReason == nil)
        #expect(state.fetchMeta == nil)
        #expect(state.isInvalidated == false)
        #expect(state.status == QueryStatus.pending)
        #expect(state.fetchStatus == FetchStatus.idle)
    }

    @Test("QueryState initialization with data")
    func initializationWithData() {
        let state = QueryState<String>(data: "test data")

        #expect(state.data == "test data")
        #expect(state.status == .success)
        #expect(state.dataUpdateCount == 0)
        #expect(state.dataUpdatedAt > 0)
    }

    @Test("QueryState initialization with error")
    func initializationWithError() {
        let error = QueryError.networkError(URLError(.notConnectedToInternet))
        let state = QueryState<String>(
            error: error,
            errorUpdateCount: 1,
            fetchFailureCount: 1,
            fetchFailureReason: error,
            status: QueryStatus.error
        )

        #expect(state.error == QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(state.status == QueryStatus.error)
        #expect(state.errorUpdateCount == 1)
        #expect(state.fetchFailureCount == 1)
        #expect(state.fetchFailureReason == QueryError.networkError(URLError(.notConnectedToInternet)))
    }

    // MARK: - Data Update Tests

    @Test("QueryState withData updates data correctly")
    func withDataUpdatesData() {
        let initialState = QueryState<String>.defaultState()
        let updatedState = initialState.withData("new data")

        #expect(updatedState.data == "new data")
        #expect(updatedState.status == .success)
        #expect(updatedState.dataUpdateCount == 1)
        #expect(updatedState.dataUpdatedAt > initialState.dataUpdatedAt)
        #expect(updatedState.error == nil) // Error should be cleared
        #expect(updatedState.fetchFailureCount == 0) // Failure count should reset
        #expect(updatedState.fetchFailureReason == nil) // Failure reason should be cleared
    }

    @Test("QueryState withData clears previous errors")
    func withDataClearsPreviousErrors() {
        let errorState = QueryState<String>(
            error: QueryError.networkError(URLError(.notConnectedToInternet)),
            errorUpdateCount: 1,
            fetchFailureCount: 2,
            fetchFailureReason: QueryError.networkError(URLError(.notConnectedToInternet)),
            status: QueryStatus.error
        )

        let successState = errorState.withData("success data")

        #expect(successState.data == "success data")
        #expect(successState.status == .success)
        #expect(successState.error == nil)
        #expect(successState.fetchFailureCount == 0)
        #expect(successState.fetchFailureReason == nil)
        #expect(successState.errorUpdateCount == 1) // Should preserve error count history
    }

    @Test("QueryState withData with nil data")
    func withDataNilData() {
        let state = QueryState<String>(data: "existing data")
        let updatedState = state.withData(nil)

        #expect(updatedState.data == nil)
        #expect(updatedState.dataUpdateCount == 0) // Should not increment for nil
        #expect(updatedState.dataUpdatedAt == state.dataUpdatedAt) // Should not update timestamp
    }

    // MARK: - Error Update Tests

    @Test("QueryState withError updates error correctly")
    func withErrorUpdatesError() {
        let initialState = QueryState<String>.defaultState()
        let errorState = initialState.withError(QueryError.networkError(URLError(.notConnectedToInternet)))

        #expect(errorState.error == QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(errorState.status == QueryStatus.error)
        #expect(errorState.errorUpdateCount == 1)
        #expect(errorState.errorUpdatedAt > initialState.errorUpdatedAt)
        #expect(errorState.fetchFailureCount == 1)
        #expect(errorState.fetchFailureReason == QueryError.networkError(URLError(.notConnectedToInternet)))
    }

    @Test("QueryState withError increments counts")
    func withErrorIncrementsCountsCorrectly() {
        let state = QueryState<String>(
            errorUpdateCount: 2,
            fetchFailureCount: 1
        )

        let errorState = state.withError(.timeout)

        #expect(errorState.errorUpdateCount == 3)
        #expect(errorState.fetchFailureCount == 2)
        #expect(errorState.fetchFailureReason == .timeout)
    }

    @Test("QueryState withError with nil error")
    func withErrorNilError() {
        let errorState = QueryState<String>(
            error: QueryError.networkError(URLError(.notConnectedToInternet)),
            errorUpdateCount: 1,
            fetchFailureCount: 1,
            status: QueryStatus.error
        )

        let clearedState = errorState.withError(nil)

        #expect(clearedState.error == nil)
        #expect(clearedState.errorUpdateCount == 1) // Should not increment for nil
        #expect(clearedState.fetchFailureCount == 1) // Should not increment for nil
    }

    // MARK: - Fetch Status Tests

    @Test("QueryState withFetchStatus updates correctly")
    func withFetchStatusUpdatesCorrectly() {
        let state = QueryState<String>.defaultState()

        let fetchingState = state.withFetchStatus(FetchStatus.fetching)
        #expect(fetchingState.fetchStatus == FetchStatus.fetching)

        let pausedState = fetchingState.withFetchStatus(.paused)
        #expect(pausedState.fetchStatus == .paused)

        let idleState = pausedState.withFetchStatus(FetchStatus.idle)
        #expect(idleState.fetchStatus == FetchStatus.idle)
    }

    @Test("QueryState withFetchStatus preserves other properties")
    func withFetchStatusPreservesOtherProperties() {
        let originalState = QueryState<String>(
            data: "test data",
            dataUpdateCount: 5,
            error: QueryError.networkError(URLError(.notConnectedToInternet)),
            errorUpdateCount: 2,
            fetchFailureCount: 1,
            isInvalidated: true,
            status: .success
        )

        let updatedState = originalState.withFetchStatus(FetchStatus.fetching)

        #expect(updatedState.data == "test data")
        #expect(updatedState.dataUpdateCount == 5)
        #expect(updatedState.error == QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(updatedState.errorUpdateCount == 2)
        #expect(updatedState.fetchFailureCount == 1)
        #expect(updatedState.isInvalidated == true)
        #expect(updatedState.status == .success)
        #expect(updatedState.fetchStatus == FetchStatus.fetching) // Only this should change
    }

    // MARK: - Invalidation Tests

    @Test("QueryState invalidation sets flag correctly")
    func invalidationSetsFlagCorrectly() {
        let state = QueryState<String>(data: "test data")
        let invalidatedState = state.invalidated()

        #expect(invalidatedState.isInvalidated == true)
        #expect(invalidatedState.data == "test data") // Data should remain
        #expect(invalidatedState.status == .success) // Status should remain
    }

    @Test("QueryState invalidation preserves all other properties")
    func invalidationPreservesOtherProperties() {
        let originalState = QueryState<String>(
            data: "test data",
            dataUpdateCount: 3,
            dataUpdatedAt: 12345,
            error: QueryError.networkError(URLError(.notConnectedToInternet)),
            errorUpdateCount: 1,
            errorUpdatedAt: 54321,
            fetchFailureCount: 2,
            fetchFailureReason: .timeout,
            fetchMeta: ["key": AnyCodable("value")],
            status: QueryStatus.error,
            fetchStatus: .paused
        )

        let invalidatedState = originalState.invalidated()

        #expect(invalidatedState.data == "test data")
        #expect(invalidatedState.dataUpdateCount == 3)
        #expect(invalidatedState.dataUpdatedAt == 12345)
        #expect(invalidatedState.error == QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(invalidatedState.errorUpdateCount == 1)
        #expect(invalidatedState.errorUpdatedAt == 54321)
        #expect(invalidatedState.fetchFailureCount == 2)
        #expect(invalidatedState.fetchFailureReason == .timeout)
        #expect(invalidatedState.fetchMeta != nil)
        #expect(invalidatedState.status == QueryStatus.error)
        #expect(invalidatedState.fetchStatus == .paused)
        #expect(invalidatedState.isInvalidated == true) // Only this should change
    }

    // MARK: - Computed Properties Tests

    @Test("QueryState computed properties work correctly")
    func computedPropertiesWorkCorrectly() {
        // Test with no data
        let emptyState = QueryState<String>.defaultState()
        #expect(emptyState.hasData == false)
        #expect(emptyState.hasError == false)
        #expect(emptyState.isFetching == false)
        #expect(emptyState.isPaused == false)
        #expect(emptyState.isIdle == true)

        // Test with data
        let dataState = QueryState<String>(data: "test")
        #expect(dataState.hasData == true)
        #expect(dataState.hasError == false)

        // Test with error
        let errorState = QueryState<String>(error: QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(errorState.hasData == false)
        #expect(errorState.hasError == true)

        // Test fetch statuses
        let fetchingState = emptyState.withFetchStatus(FetchStatus.fetching)
        #expect(fetchingState.isFetching == true)
        #expect(fetchingState.isPaused == false)
        #expect(fetchingState.isIdle == false)

        let pausedState = emptyState.withFetchStatus(.paused)
        #expect(pausedState.isFetching == false)
        #expect(pausedState.isPaused == true)
        #expect(pausedState.isIdle == false)
    }

    @Test("QueryState date conversions work correctly")
    func dateConversionsWorkCorrectly() {
        let timestamp: Int64 = 1_640_995_200_000 // Jan 1, 2022 00:00:00 UTC
        let expectedDate = Date(timeIntervalSince1970: 1_640_995_200.0)

        let state = QueryState<String>(
            dataUpdatedAt: timestamp,
            errorUpdatedAt: timestamp
        )

        #expect(state.dataUpdatedDate == expectedDate)
        #expect(state.errorUpdatedDate == expectedDate)

        // Test with zero timestamps
        let zeroState = QueryState<String>(
            dataUpdatedAt: 0,
            errorUpdatedAt: 0
        )

        #expect(zeroState.dataUpdatedDate == nil)
        #expect(zeroState.errorUpdatedDate == nil)
    }

    // MARK: - Integration Tests

    @Test("QueryState state transitions work correctly")
    func stateTransitionsWorkCorrectly() {
        // Start with default state
        var state = QueryState<String>.defaultState()
        #expect(state.status == QueryStatus.pending)
        #expect(state.fetchStatus == FetchStatus.idle)

        // Start fetching
        state = state.withFetchStatus(FetchStatus.fetching)
        #expect(state.fetchStatus == FetchStatus.fetching)

        // Successful fetch
        state = state.withData("success data")
        #expect(state.status == .success)
        #expect(state.data == "success data")

        // Stop fetching
        state = state.withFetchStatus(FetchStatus.idle)
        #expect(state.fetchStatus == FetchStatus.idle)

        // Invalidate
        state = state.invalidated()
        #expect(state.isInvalidated == true)
        #expect(state.data == "success data") // Data should still be there

        // Start new fetch
        state = state.withFetchStatus(FetchStatus.fetching)

        // Fetch fails
        state = state.withError(QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(state.status == QueryStatus.error)
        #expect(state.error == QueryError.networkError(URLError(.notConnectedToInternet)))
        #expect(state.fetchFailureCount == 1)

        // Stop fetching
        state = state.withFetchStatus(FetchStatus.idle)
        #expect(state.fetchStatus == FetchStatus.idle)
    }
}

// MARK: - Test Helpers

enum TestError: Error, Sendable, Codable, Equatable {
    case network
    case timeout
    case generic
}
