// UseQueryTests.swift - Tests for UseQuery SwiftUI component

import Testing
import SwiftUI
@testable import SwiftUIQuery

@MainActor
struct UseQueryTests {
    // MARK: - Test Data Models

    struct TestUser: Sendable, Codable {
        let id: String
        let name: String
    }

    struct TestPost: Sendable, Codable {
        let id: String
        let title: String
        let authorId: String
    }

    // MARK: - Initialization Tests

    @Test("UseQuery initializes with query options")
    func initializeWithQueryOptions() {
        let options = QueryOptions<TestUser, String>(
            queryKey: "test-user",
            queryFn: { _ in TestUser(id: "1", name: "Test User") }
        )

        let useQuery = UseQuery(options: options) { result in
            Text("User: \(result.data?.name ?? "Loading")")
        }

        #expect(useQuery.testObserver.options.queryKey == "test-user")
        #expect(useQuery.testObserver.options.enabled == true)
    }

    @Test("UseQuery initializes with convenience String initializer")
    func initializeWithStringKey() {
        let useQuery = UseQuery(
            queryKey: "user-123",
            queryFn: { _ in TestUser(id: "123", name: "User 123") }
        ) { result in
            Text("User: \(result.data?.name ?? "Loading")")
        }

        #expect(useQuery.testObserver.options.queryKey == "user-123")
        #expect(useQuery.testObserver.options.staleTime == 0)
        #expect(useQuery.testObserver.options.gcTime == defaultGcTime)
        #expect(useQuery.testObserver.options.enabled == true)
    }

    @Test("UseQuery initializes with convenience Array initializer")
    func initializeWithArrayKey() {
        let useQuery = UseQuery(
            queryKey: ["posts", "user-123"],
            queryFn: { _ in [TestPost(id: "1", title: "Post 1", authorId: "123")] }
        ) { result in
            Text("Posts: \(result.data?.count ?? 0)")
        }

        #expect(useQuery.testObserver.options.queryKey == ["posts", "user-123"])
        #expect(useQuery.testObserver.options.staleTime == 0)
        #expect(useQuery.testObserver.options.gcTime == defaultGcTime)
        #expect(useQuery.testObserver.options.enabled == true)
    }

    @Test("UseQuery initializes with Dictionary initializer")
    func initializeWithDictionaryKey() {
        let queryKey: [String: String] = ["type": "user", "id": "123", "status": "active"]

        let useQuery = UseQuery(
            queryKey: queryKey,
            queryFn: { (key: [String: String]) in
                TestUser(id: key["id"] ?? "", name: "User \(key["id"] ?? "")")
            }
        ) { result in
            Text("User: \(result.data?.name ?? "Loading")")
        }

        #expect(useQuery.testObserver.options.queryKey == queryKey)
        #expect(useQuery.testObserver.options.staleTime == 0)
        #expect(useQuery.testObserver.options.gcTime == defaultGcTime)
        #expect(useQuery.testObserver.options.enabled == true)
    }

    @Test("UseQuery initializes with custom parameters")
    func initializeWithCustomParameters() {
        let useQuery = UseQuery(
            queryKey: "posts",
            queryFn: { _ in [TestPost(id: "1", title: "Post 1", authorId: "123")] },
            staleTime: 60,
            gcTime: 300,
            enabled: false
        ) { result in
            Text("Posts: \(result.data?.count ?? 0)")
        }

        #expect(useQuery.testObserver.options.queryKey == "posts")
        #expect(useQuery.testObserver.options.staleTime == 60)
        #expect(useQuery.testObserver.options.gcTime == 300)
        #expect(useQuery.testObserver.options.enabled == false)
    }

    @Test("UseQuery uses shared QueryClient by default")
    func usesSharedQueryClient() {
        let useQuery = UseQuery(
            queryKey: "test",
            queryFn: { _ in "test data" }
        ) { result in
            Text("Data: \(result.data ?? "Loading")")
        }

        // The observer should use the shared query client
        #expect(useQuery.testObserver.client === QueryClientProvider.shared.queryClient)
    }

    @Test("UseQuery accepts custom QueryClient")
    func acceptsCustomQueryClient() {
        let customClient = QueryClient()

        let useQuery = UseQuery(
            queryKey: "test",
            queryFn: { _ in "test data" },
            queryClient: customClient
        ) { result in
            Text("Data: \(result.data ?? "Loading")")
        }

        // The observer should use the custom query client
        #expect(useQuery.testObserver.client === customClient)
    }

    // MARK: - Preview Helper Tests

    #if DEBUG
        @Test("UseQuery preview helper works")
        func previewHelper() {
            let mockUser = TestUser(id: "preview", name: "Preview User")

            let useQuery = UseQuery.preview(
                queryKey: "preview-user",
                mockData: mockUser
            ) { result in
                Text("User: \(result.data?.name ?? "Loading")")
            }

            #expect(useQuery.testObserver.options.queryKey == "preview-user")
        }

        @Test("UseQuery preview loading helper")
        func previewLoadingHelper() {
            let useQuery = UseQuery<TestUser, String, Text>.previewLoading(
                queryKey: "loading-user"
            ) { result in
                Text("User: \(result.data?.name ?? "Loading")")
            }

            #expect(useQuery.testObserver.options.queryKey == "loading-user")
        }

        @Test("UseQuery preview error helper")
        func previewErrorHelper() {
            let useQuery = UseQuery<TestUser, String, Text>.previewError(
                queryKey: "error-user",
                error: QueryError.networkError(URLError(.notConnectedToInternet))
            ) { result in
                Text("User: \(result.data?.name ?? "Error")")
            }

            #expect(useQuery.testObserver.options.queryKey == "error-user")
        }
    #endif

    // MARK: - QueryKey Extension Tests

    @Test("String QueryKey extension works")
    func stringQueryKeyExtension() {
        let key = "test-key"
        #expect(key.queryHash == "test-key")
    }

    @Test("Array QueryKey extension works")
    func arrayQueryKeyExtension() {
        let key = ["posts", "user-123"]
        // Arrays use JSON encoding for queryHash
        #expect(key.queryHash == "[\"posts\",\"user-123\"]")
    }

    @Test("Array QueryKey extension generates unique hashes")
    func arrayQueryKeyUniqueness() {
        let key1 = ["user-123", "posts"]
        let key2 = ["posts", "user-123"]
        // Different order means different hash
        #expect(key1.queryHash != key2.queryHash)

        let key3 = ["posts", "user-456"]
        let key4 = ["posts", "user-123"]
        // Different values mean different hash
        #expect(key3.queryHash != key4.queryHash)
    }

    @Test("Dictionary QueryKey extension works")
    func dictionaryQueryKeyExtension() {
        let key: [String: String] = ["type": "user", "id": "123"]
        // Dictionaries use JSON encoding with sorted keys for queryHash
        let expectedHash = "{\"id\":\"123\",\"type\":\"user\"}"
        #expect(key.queryHash == expectedHash)
    }

    @Test("Dictionary QueryKey generates consistent hashes")
    func dictionaryQueryKeyConsistency() {
        let key1: [String: String] = ["type": "post", "id": "456", "status": "published"]
        let key2: [String: String] = ["status": "published", "type": "post", "id": "456"]
        // Same keys and values in different order should produce same hash (sorted keys)
        #expect(key1.queryHash == key2.queryHash)

        let key3: [String: String] = ["type": "post", "id": "789"]
        let key4: [String: String] = ["type": "post", "id": "456"]
        // Different values should produce different hashes
        #expect(key3.queryHash != key4.queryHash)
    }

    // MARK: - Environment Support Tests

    @Test("Environment QueryClient key exists")
    func environmentQueryClientKey() {
        // Test that the environment key can be accessed
        _ = EmptyView().environment(\.queryClient, QueryClient())
        // If this compiles, the environment key works
        #expect(Bool(true))
    }

    @Test("QueryClientProviderModifier can be created")
    func queryClientProviderModifier() {
        let client = QueryClient()
        let modifier = QueryClientProviderModifier(queryClient: client)

        _ = EmptyView().modifier(modifier)
        // If this compiles, the modifier works
        #expect(Bool(true))
    }

    @Test("QueryClient view modifier extension works")
    func queryClientViewModifier() {
        let client = QueryClient()
        _ = EmptyView().queryClient(client)
        // If this compiles, the extension works
        #expect(Bool(true))
    }

    // MARK: - QueryError Extension Tests

    @Test("QueryError common cases work")
    func queryErrorCommonCases() {
        let networkError = QueryError.networkError(URLError(.notConnectedToInternet))
        #expect(networkError.code == "NETWORK_ERROR")
        #expect(networkError.message == "Network error occurred")

        let cancelled = QueryError.cancelled
        #expect(cancelled.code == "CANCELLED")
        #expect(cancelled.message == "Query was cancelled")

        let timeout = QueryError.timeout
        #expect(timeout.code == "TIMEOUT")
        #expect(timeout.message == "Query timed out")

        let invalidConfig = QueryError.invalidConfiguration("Invalid setup")
        #expect(invalidConfig.code == "INVALID_CONFIGURATION")
        #expect(invalidConfig.message == "Invalid setup")

        let queryFailed = QueryError.queryFailed(URLError(.badURL))
        #expect(queryFailed.code == "QUERY_FAILED")
        #expect(queryFailed.message == "Query failed")
    }

    // MARK: - Integration Tests

    @Test("UseQuery integrates with QueryObserver lifecycle")
    func integratesWithQueryObserverLifecycle() async {
        let client = QueryClient()

        let useQuery = UseQuery(
            queryKey: "test-integration",
            queryFn: { _ in
                TestUser(id: "1", name: "User 1")
            },
            queryClient: client
        ) { result in
            Text("User: \(result.data?.name ?? "Loading")")
        }

        // Initially, observer should not be subscribed
        #expect(!useQuery.testObserver.isSubscribed)

        // Observer should have the correct configuration
        #expect(useQuery.testObserver.options.queryKey == "test-integration")
        #expect(useQuery.testObserver.client === client)
    }

    @Test("UseQuery options correctly configure QueryObserver")
    func optionsConfigureQueryObserver() {
        let useQuery = UseQuery(
            queryKey: "config-test",
            queryFn: { _ in "test-data" },
            staleTime: 120,
            gcTime: 600,
            enabled: false
        ) { result in
            Text("Data: \(result.data ?? "Loading")")
        }

        let options = useQuery.testObserver.options
        #expect(options.queryKey == "config-test")
        #expect(options.staleTime == 120)
        #expect(options.gcTime == 600)
        #expect(options.enabled == false)
        #expect(options.refetchOnAppear == RefetchOnAppear.ifStale)
        #expect(options.structuralSharing == true)
        #expect(options.networkMode == NetworkMode.online)
    }

    @Test("UseQuery result reflects QueryObserver state")
    func resultReflectsQueryObserverState() {
        let useQuery = UseQuery(
            queryKey: "result-test",
            queryFn: { _ in TestUser(id: "1", name: "Test User") }
        ) { result in
            Text("User: \(result.data?.name ?? "Loading")")
        }

        // Initial state should be pending with no data
        let result = useQuery.testObserver.result
        #expect(result.data == nil)
        #expect(result.isPending == true)
        #expect(result.isLoading == false) // Not fetching initially
        #expect(result.isSuccess == false)
        #expect(result.isError == false)
    }
}

// MARK: - QueryClient Provider Tests

@MainActor
struct QueryClientProviderTests {
    @Test("QueryClientProvider shared instance is singleton")
    func sharedInstanceIsSingleton() {
        let provider1 = QueryClientProvider.shared
        let provider2 = QueryClientProvider.shared

        #expect(provider1 === provider2)
        #expect(provider1.queryClient === provider2.queryClient)
    }

    @Test("QueryClientProvider automatically mounts client")
    func automaticallyMountsClient() {
        let provider = QueryClientProvider.shared

        // The client should be automatically mounted when the provider is created
        // We can verify the client exists and has the expected type
        #expect(type(of: provider.queryClient) == QueryClient.self)
    }

    @Test("QueryClientProvider client is properly configured")
    func clientIsProperlyConfigured() {
        // Create a new QueryClient for testing instead of using shared instance
        // to avoid interference from other tests
        let client = QueryClient()

        // Client should be properly initialized
        #expect(type(of: client.cache) == QueryCache.self)
        #expect(client.cache.isEmpty == true) // Initially empty
    }
}
