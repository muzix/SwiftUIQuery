import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("QueryObserverResult Tests")
@MainActor
struct QueryObserverResultTests {
    // MARK: - Initialization Tests

    @Test("QueryObserverResult initializes with QueryState")
    func initializesWithQueryState() {
        let queryState = QueryState<String>(data: "test data")
        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.data == "test data")
        #expect(result.isStale == false)
    }

    @Test("QueryObserverResult with empty state")
    func initializesWithEmptyState() {
        let queryState = QueryState<String>.defaultState()
        let result = QueryObserverResult(queryState: queryState, isStale: true)

        #expect(result.data == nil)
        #expect(result.error == nil)
        #expect(result.isStale == true)
    }

    // MARK: - Data Properties Tests

    @Test("QueryObserverResult data properties from QueryState")
    func dataPropertiesFromQueryState() {
        let error = QueryError(message: "Test error", code: "TEST_001")
        let meta = ["key": AnyCodable("value")]
        let dataTimestamp: Int64 = 1_640_995_200_000 // Jan 1, 2022
        let errorTimestamp: Int64 = 1_640_995_300_000 // Jan 1, 2022 + 100s

        let queryState = QueryState<String>(
            data: "test data",
            dataUpdateCount: 3,
            dataUpdatedAt: dataTimestamp,
            error: error,
            errorUpdateCount: 2,
            errorUpdatedAt: errorTimestamp,
            fetchFailureCount: 1,
            fetchFailureReason: error,
            fetchMeta: meta
        )

        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.data == "test data")
        #expect(result.error == error)
        #expect(result.dataUpdateCount == 3)
        #expect(result.errorUpdateCount == 2)
        #expect(result.failureCount == 1)
        #expect(result.failureReason == error)
    }

    @Test("QueryObserverResult timestamp conversions")
    func timestampConversions() {
        let dataTimestamp: Int64 = 1_640_995_200_000 // Jan 1, 2022 00:00:00 UTC
        let errorTimestamp: Int64 = 1_640_995_300_000 // Jan 1, 2022 00:01:40 UTC

        let expectedDataDate = Date(timeIntervalSince1970: 1_640_995_200.0)
        let expectedErrorDate = Date(timeIntervalSince1970: 1_640_995_300.0)

        let queryState = QueryState<String>(
            dataUpdatedAt: dataTimestamp,
            errorUpdatedAt: errorTimestamp
        )

        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.dataUpdatedAt == expectedDataDate)
        #expect(result.errorUpdatedAt == expectedErrorDate)
    }

    @Test("QueryObserverResult nil timestamps")
    func nilTimestamps() {
        let queryState = QueryState<String>(
            dataUpdatedAt: 0,
            errorUpdatedAt: 0
        )

        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.dataUpdatedAt == nil)
        #expect(result.errorUpdatedAt == nil)
    }

    // MARK: - Computed Status Properties Tests

    @Test("QueryObserverResult fetch status properties")
    func fetchStatusProperties() {
        // Test fetching
        let fetchingState = QueryState<String>(fetchStatus: FetchStatus.fetching)
        let fetchingResult = QueryObserverResult(queryState: fetchingState, isStale: false)

        #expect(fetchingResult.isFetching == true)
        #expect(fetchingResult.isPaused == false)

        // Test paused
        let pausedState = QueryState<String>(fetchStatus: .paused)
        let pausedResult = QueryObserverResult(queryState: pausedState, isStale: false)

        #expect(pausedResult.isFetching == false)
        #expect(pausedResult.isPaused == true)

        // Test idle
        let idleState = QueryState<String>(fetchStatus: FetchStatus.idle)
        let idleResult = QueryObserverResult(queryState: idleState, isStale: false)

        #expect(idleResult.isFetching == false)
        #expect(idleResult.isPaused == false)
    }

    @Test("QueryObserverResult query status properties")
    func queryStatusProperties() {
        // Test pending
        let pendingState = QueryState<String>(status: QueryStatus.pending)
        let pendingResult = QueryObserverResult(queryState: pendingState, isStale: false)

        #expect(pendingResult.isPending == true)
        #expect(pendingResult.isSuccess == false)
        #expect(pendingResult.isError == false)

        // Test success
        let successState = QueryState<String>(
            data: "data",
            status: .success
        )
        let successResult = QueryObserverResult(queryState: successState, isStale: false)

        #expect(successResult.isPending == false)
        #expect(successResult.isSuccess == true)
        #expect(successResult.isError == false)

        // Test error
        let errorState = QueryState<String>(
            error: QueryError(message: "Error"),
            status: QueryStatus.error
        )
        let errorResult = QueryObserverResult(queryState: errorState, isStale: false)

        #expect(errorResult.isPending == false)
        #expect(errorResult.isSuccess == false)
        #expect(errorResult.isError == true)
    }

    @Test("QueryObserverResult loading state computation")
    func loadingStateComputation() {
        // Loading = pending + fetching
        let loadingState = QueryState<String>(
            status: QueryStatus.pending,
            fetchStatus: FetchStatus.fetching
        )
        let loadingResult = QueryObserverResult(queryState: loadingState, isStale: false)

        #expect(loadingResult.isLoading == true)
        #expect(loadingResult.isPending == true)
        #expect(loadingResult.isFetching == true)

        // Not loading if not pending
        let notLoadingState1 = QueryState<String>(
            data: "data",
            status: .success,
            fetchStatus: FetchStatus.fetching
        )
        let notLoadingResult1 = QueryObserverResult(queryState: notLoadingState1, isStale: false)

        #expect(notLoadingResult1.isLoading == false)
        #expect(notLoadingResult1.isPending == false)
        #expect(notLoadingResult1.isFetching == true)

        // Not loading if not fetching
        let notLoadingState2 = QueryState<String>(
            status: QueryStatus.pending,
            fetchStatus: FetchStatus.idle
        )
        let notLoadingResult2 = QueryObserverResult(queryState: notLoadingState2, isStale: false)

        #expect(notLoadingResult2.isLoading == false)
        #expect(notLoadingResult2.isPending == true)
        #expect(notLoadingResult2.isFetching == false)
    }

    @Test("QueryObserverResult refetching state computation")
    func refetchingStateComputation() {
        // Refetching = fetching + not pending
        let refetchingState = QueryState<String>(
            data: "existing data",
            status: .success,
            fetchStatus: FetchStatus.fetching
        )
        let refetchingResult = QueryObserverResult(queryState: refetchingState, isStale: false)

        #expect(refetchingResult.isRefetching == true)
        #expect(refetchingResult.isPending == false)
        #expect(refetchingResult.isFetching == true)

        // Not refetching if pending
        let notRefetchingState1 = QueryState<String>(
            status: QueryStatus.pending,
            fetchStatus: FetchStatus.fetching
        )
        let notRefetchingResult1 = QueryObserverResult(queryState: notRefetchingState1, isStale: false)

        #expect(notRefetchingResult1.isRefetching == false)
        #expect(notRefetchingResult1.isPending == true)
        #expect(notRefetchingResult1.isFetching == true)

        // Not refetching if not fetching
        let notRefetchingState2 = QueryState<String>(
            data: "data",
            status: .success,
            fetchStatus: FetchStatus.idle
        )
        let notRefetchingResult2 = QueryObserverResult(queryState: notRefetchingState2, isStale: false)

        #expect(notRefetchingResult2.isRefetching == false)
        #expect(notRefetchingResult2.isPending == false)
        #expect(notRefetchingResult2.isFetching == false)
    }

    @Test("QueryObserverResult stale state from parameter")
    func staleStateFromParameter() {
        let queryState = QueryState<String>(data: "data")

        let staleResult = QueryObserverResult(queryState: queryState, isStale: true)
        #expect(staleResult.isStale == true)

        let freshResult = QueryObserverResult(queryState: queryState, isStale: false)
        #expect(freshResult.isStale == false)
    }

    // MARK: - Complex State Scenarios Tests

    @Test("QueryObserverResult initial loading scenario")
    func initialLoadingScenario() {
        // First load: pending + fetching
        let queryState = QueryState<String>(
            status: QueryStatus.pending,
            fetchStatus: FetchStatus.fetching
        )
        let result = QueryObserverResult(queryState: queryState, isStale: true)

        #expect(result.data == nil)
        #expect(result.error == nil)
        #expect(result.isPending == true)
        #expect(result.isLoading == true)
        #expect(result.isFetching == true)
        #expect(result.isRefetching == false)
        #expect(result.isSuccess == false)
        #expect(result.isError == false)
        #expect(result.isStale == true)
    }

    @Test("QueryObserverResult successful load scenario")
    func successfulLoadScenario() {
        let queryState = QueryState<String>(
            data: "loaded data",
            dataUpdateCount: 1,
            status: .success,
            fetchStatus: FetchStatus.idle
        )
        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.data == "loaded data")
        #expect(result.error == nil)
        #expect(result.isPending == false)
        #expect(result.isLoading == false)
        #expect(result.isFetching == false)
        #expect(result.isRefetching == false)
        #expect(result.isSuccess == true)
        #expect(result.isError == false)
        #expect(result.isStale == false)
        #expect(result.dataUpdateCount == 1)
    }

    @Test("QueryObserverResult background refetch scenario")
    func backgroundRefetchScenario() {
        let queryState = QueryState<String>(
            data: "cached data",
            dataUpdateCount: 1,
            status: .success,
            fetchStatus: FetchStatus.fetching
        )
        let result = QueryObserverResult(queryState: queryState, isStale: true)

        #expect(result.data == "cached data")
        #expect(result.error == nil)
        #expect(result.isPending == false)
        #expect(result.isLoading == false)
        #expect(result.isFetching == true)
        #expect(result.isRefetching == true)
        #expect(result.isSuccess == true)
        #expect(result.isError == false)
        #expect(result.isStale == true)
    }

    @Test("QueryObserverResult error scenario")
    func errorScenario() {
        let error = QueryError(message: "Network error", code: "NETWORK_001")
        let queryState = QueryState<String>(
            error: error,
            errorUpdateCount: 1,
            fetchFailureCount: 1,
            fetchFailureReason: error,
            status: QueryStatus.error,
            fetchStatus: FetchStatus.idle
        )
        let result = QueryObserverResult(queryState: queryState, isStale: true)

        #expect(result.data == nil)
        #expect(result.error == error)
        #expect(result.isPending == false)
        #expect(result.isLoading == false)
        #expect(result.isFetching == false)
        #expect(result.isRefetching == false)
        #expect(result.isSuccess == false)
        #expect(result.isError == true)
        #expect(result.isStale == true)
        #expect(result.errorUpdateCount == 1)
        #expect(result.failureCount == 1)
        #expect(result.failureReason == error)
    }

    @Test("QueryObserverResult error with existing data scenario")
    func errorWithExistingDataScenario() {
        // Simulate a refetch that failed but we still have old data
        let error = QueryError(message: "Refetch failed")
        let queryState = QueryState<String>(
            data: "old data",
            dataUpdateCount: 1,
            error: error,
            errorUpdateCount: 1,
            fetchFailureCount: 1,
            fetchFailureReason: error,
            status: QueryStatus.error,
            fetchStatus: FetchStatus.idle
        )
        let result = QueryObserverResult(queryState: queryState, isStale: true)

        #expect(result.data == "old data")
        #expect(result.error == error)
        #expect(result.isSuccess == false)
        #expect(result.isError == true)
        #expect(result.dataUpdateCount == 1)
        #expect(result.errorUpdateCount == 1)
    }

    @Test("QueryObserverResult paused scenario")
    func pausedScenario() {
        let queryState = QueryState<String>(
            data: "cached data",
            status: .success,
            fetchStatus: .paused
        )
        let result = QueryObserverResult(queryState: queryState, isStale: true)

        #expect(result.data == "cached data")
        #expect(result.isPending == false)
        #expect(result.isLoading == false)
        #expect(result.isFetching == false)
        #expect(result.isPaused == true)
        #expect(result.isRefetching == false)
        #expect(result.isSuccess == true)
        #expect(result.isStale == true)
    }

    // MARK: - Edge Cases Tests

    @Test("QueryObserverResult with complex error types")
    func complexErrorTypes() {
        let queryError = QueryError(
            message: "Complex error",
            code: "COMPLEX_001",
            underlyingError: NSError(domain: "TestDomain", code: 42)
        )

        let queryState = QueryState<String>(
            error: queryError,
            status: QueryStatus.error
        )
        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.error?.message == "Complex error")
        #expect(result.error?.code == "COMPLEX_001")
        #expect(result.error?.underlyingError != nil)
        #expect(result.isError == true)
    }

    @Test("QueryObserverResult state consistency")
    func stateConsistency() {
        // Test each scenario individually to avoid large tuple violation
        testScenario(
            QueryStatus.pending,
            FetchStatus.idle,
            pending: true,
            success: false,
            error: false,
            loading: false,
            refetching: false
        )
        testScenario(
            QueryStatus.pending,
            FetchStatus.fetching,
            pending: true,
            success: false,
            error: false,
            loading: true,
            refetching: false
        )
        testScenario(
            QueryStatus.pending,
            .paused,
            pending: true,
            success: false,
            error: false,
            loading: false,
            refetching: false
        )
        testScenario(
            .success,
            FetchStatus.idle,
            pending: false,
            success: true,
            error: false,
            loading: false,
            refetching: false
        )
        testScenario(
            .success,
            FetchStatus.fetching,
            pending: false,
            success: true,
            error: false,
            loading: false,
            refetching: true
        )
        testScenario(.success, .paused, pending: false, success: true, error: false, loading: false, refetching: false)
        testScenario(
            QueryStatus.error,
            FetchStatus.idle,
            pending: false,
            success: false,
            error: true,
            loading: false,
            refetching: false
        )
        testScenario(
            QueryStatus.error,
            FetchStatus.fetching,
            pending: false,
            success: false,
            error: true,
            loading: false,
            refetching: true
        )
        testScenario(
            QueryStatus.error,
            .paused,
            pending: false,
            success: false,
            error: true,
            loading: false,
            refetching: false
        )
    }

    private func testScenario(
        _ status: QueryStatus,
        _ fetchStatus: FetchStatus,
        pending: Bool,
        success: Bool,
        error: Bool,
        loading: Bool,
        refetching: Bool
    ) {
        let queryState = QueryState<String>(
            data: status == .success ? "data" : nil,
            error: status == QueryStatus.error ? QueryError(message: "error") : nil,
            status: status,
            fetchStatus: fetchStatus
        )
        let result = QueryObserverResult(queryState: queryState, isStale: false)

        #expect(result.isPending == pending, "Pending mismatch for \(status)/\(fetchStatus)")
        #expect(result.isSuccess == success, "Success mismatch for \(status)/\(fetchStatus)")
        #expect(result.isError == error, "Error mismatch for \(status)/\(fetchStatus)")
        #expect(result.isLoading == loading, "Loading mismatch for \(status)/\(fetchStatus)")
        #expect(result.isRefetching == refetching, "Refetching mismatch for \(status)/\(fetchStatus)")
    }
}
