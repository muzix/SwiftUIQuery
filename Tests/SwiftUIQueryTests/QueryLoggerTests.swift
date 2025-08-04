// QueryLoggerTests.swift - Tests for centralized logging system

import Testing
@testable import SwiftUIQuery

@MainActor
struct QueryLoggerTests {
    @Test
    func loggerDefaultState() {
        let logger = QueryLogger.shared

        // Reset to default state first (since it's a singleton)
        logger.disableAll()
        logger.logQueryClient = true
        logger.logQuery = true
        logger.logQueryObserver = true

        // By default, logging should be disabled
        #expect(!logger.isEnabled)
        #expect(logger.logQueryClient)
        #expect(logger.logQuery)
        #expect(logger.logQueryObserver)
    }

    @Test
    func loggerEnableAll() {
        let logger = QueryLogger.shared

        // Test enable all
        logger.enableAll()

        #expect(logger.isEnabled)
        #expect(logger.logQueryClient)
        #expect(logger.logQuery)
        #expect(logger.logQueryObserver)
    }

    @Test
    func loggerDisableAll() {
        let logger = QueryLogger.shared

        // First enable, then disable
        logger.enableAll()
        logger.disableAll()

        #expect(!logger.isEnabled)
        // Individual flags should remain as they were
        #expect(logger.logQueryClient)
        #expect(logger.logQuery)
        #expect(logger.logQueryObserver)
    }

    @Test
    func loggerSelectiveEnable() {
        let logger = QueryLogger.shared

        // Test QueryClient only
        logger.enableQueryClientOnly()
        #expect(logger.isEnabled)
        #expect(logger.logQueryClient)
        #expect(!logger.logQuery)
        #expect(!logger.logQueryObserver)

        // Test Query only
        logger.enableQueryOnly()
        #expect(logger.isEnabled)
        #expect(!logger.logQueryClient)
        #expect(logger.logQuery)
        #expect(!logger.logQueryObserver)

        // Test QueryObserver only
        logger.enableQueryObserverOnly()
        #expect(logger.isEnabled)
        #expect(!logger.logQueryClient)
        #expect(!logger.logQuery)
        #expect(logger.logQueryObserver)
    }

    @Test
    func loggingIntegrationWithQueryClient() async {
        // Test that logging can be enabled and cache operations work
        let logger = QueryLogger.shared

        // Enable logging
        logger.enableAll()

        let client = QueryClient()

        // Test cache operations with logging enabled
        let queryKey = ArrayQueryKey("test", "user")
        let testData = TestUser(id: "123", name: "Test User", email: "test@example.com")

        // This should trigger cache miss -> cache hit logging
        let data1 = client.setQueryData(queryKey: queryKey, data: testData)
        let data2: TestUser? = client.getQueryData(queryKey: queryKey)

        #expect(data1.id == testData.id)
        #expect(data2?.id == testData.id)

        // Disable logging
        logger.disableAll()

        // Operations should still work without logging
        let data3: TestUser? = client.getQueryData(queryKey: queryKey)
        #expect(data3?.id == testData.id)
    }
}
