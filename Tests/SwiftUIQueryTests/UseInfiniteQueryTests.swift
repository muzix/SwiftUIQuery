import Testing
import SwiftUI
@testable import SwiftUIQuery

/// Test data structures for infinite query tests
struct PostPage: Sendable, Codable, Equatable {
    let posts: [Post]
    let nextCursor: Int?

    static func create(start: Int, count: Int) -> PostPage {
        let posts = (start ..< (start + count)).map { id in
            Post(id: id, title: "Post \(id)", content: "Content for post \(id)")
        }
        let nextCursor = start + count < 100 ? start + count : nil // Simulate 100 total posts
        return PostPage(posts: posts, nextCursor: nextCursor)
    }
}

struct Post: Sendable, Codable, Equatable {
    let id: Int
    let title: String
    let content: String
}

// MARK: - UseInfiniteQuery Tests

@Suite("UseInfiniteQuery Tests")
@MainActor
struct UseInfiniteQueryTests {
    @Test("UseInfiniteQuery initializes with options")
    func useInfiniteQueryInitializesWithOptions() throws {
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let useInfiniteQuery = UseInfiniteQuery(options: options) { _ in
            EmptyView()
        }

        #expect(useInfiniteQuery.testObserver.options.queryKey == "posts")
        #expect(useInfiniteQuery.testObserver.options.initialPageParam == 0)
    }

    @Test("UseInfiniteQuery initializes with convenience parameters")
    func useInfiniteQueryInitializesWithConvenienceParameters() throws {
        let useInfiniteQuery = UseInfiniteQuery<PostPage, String, Int, EmptyView>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        ) { _ in
            EmptyView()
        }

        #expect(useInfiniteQuery.testObserver.options.queryKey == "posts")
        #expect(useInfiniteQuery.testObserver.options.initialPageParam == 0)
    }

    @Test("UseInfiniteQuery result reflects InfiniteQueryObserver state")
    func useInfiniteQueryResultReflectsObserverState() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let useInfiniteQuery = UseInfiniteQuery(
            options: options,
            queryClient: queryClient
        ) { _ in
            EmptyView()
        }

        let observer = useInfiniteQuery.testObserver

        // Initially should be pending
        #expect(observer.isPending == true)
        #expect(observer.isLoading == false) // Not loading until subscribed
        #expect(observer.data == nil || observer.data?.isEmpty == true)
    }

    @Test("UseInfiniteQuery integrates with InfiniteQueryObserver lifecycle")
    func useInfiniteQueryIntegratesWithObserverLifecycle() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let useInfiniteQuery = UseInfiniteQuery(
            options: options,
            queryClient: queryClient
        ) { _ in
            EmptyView()
        }

        let observer = useInfiniteQuery.testObserver

        // Observer should not be subscribed initially
        #expect(observer.isSubscribed == false)

        // Subscribe manually (normally done by SwiftUI lifecycle)
        observer.subscribe()
        #expect(observer.isSubscribed == true)

        // Unsubscribe
        observer.unsubscribe()
        #expect(observer.isSubscribed == false)
    }

    @Test("UseInfiniteQuery accepts custom QueryClient")
    func useInfiniteQueryAcceptsCustomQueryClient() throws {
        let customClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let useInfiniteQuery = UseInfiniteQuery(
            options: options,
            queryClient: customClient
        ) { _ in
            EmptyView()
        }

        #expect(useInfiniteQuery.testObserver.client === customClient)
    }

    @Test("UseInfiniteQuery convenience initializer works")
    func useInfiniteQueryConvenienceInitializerWorks() throws {
        let useInfiniteQuery = UseInfiniteQuery(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            }
        ) { _ in
            EmptyView()
        }

        #expect(useInfiniteQuery.testObserver.options.queryKey == "posts")
    }
}

// MARK: - InfiniteQueryObserver Tests

@Suite("InfiniteQueryObserver Tests")
@MainActor
struct InfiniteQueryObserverTests {
    @Test("InfiniteQueryObserver initializes correctly")
    func infiniteQueryObserverInitializesCorrectly() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)

        #expect(observer.client === queryClient)
        #expect(observer.options.queryKey == "posts")
        #expect(observer.isSubscribed == false)
        #expect(observer.isPending == true)
        #expect(observer.data == nil || observer.data?.isEmpty == true)
    }

    @Test("InfiniteQueryObserver convenience properties reflect result")
    func infiniteQueryObserverConveniencePropertiesReflectResult() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)

        // Test that convenience properties match result properties
        #expect(observer.data?.pages.count == observer.result.data?.pages.count)
        #expect(observer.error == observer.result.error)
        #expect(observer.isLoading == observer.result.isLoading)
        #expect(observer.isFetching == observer.result.isFetching)
        #expect(observer.isSuccess == observer.result.isSuccess)
        #expect(observer.isError == observer.result.isError)
        #expect(observer.isPending == observer.result.isPending)
        #expect(observer.isRefetching == observer.result.isRefetching)
        #expect(observer.isStale == observer.result.isStale)
        #expect(observer.isPaused == observer.result.isPaused)
        #expect(observer.hasNextPage == observer.result.hasNextPage)
        #expect(observer.hasPreviousPage == observer.result.hasPreviousPage)
        #expect(observer.isFetchingNextPage == observer.result.isFetchingNextPage)
        #expect(observer.isFetchingPreviousPage == observer.result.isFetchingPreviousPage)
        #expect(observer.isFetchNextPageError == observer.result.isFetchNextPageError)
        #expect(observer.isFetchPreviousPageError == observer.result.isFetchPreviousPageError)
    }

    @Test("InfiniteQueryObserver subscribe/unsubscribe lifecycle")
    func infiniteQueryObserverSubscribeUnsubscribeLifecycle() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)

        // Initially not subscribed
        #expect(observer.isSubscribed == false)

        // Subscribe
        observer.subscribe()
        #expect(observer.isSubscribed == true)

        // Double subscribe should be safe
        observer.subscribe()
        #expect(observer.isSubscribed == true)

        // Unsubscribe
        observer.unsubscribe()
        #expect(observer.isSubscribed == false)

        // Double unsubscribe should be safe
        observer.unsubscribe()
        #expect(observer.isSubscribed == false)
    }

    @Test("InfiniteQueryObserver setOptions updates enabled state")
    func infiniteQueryObserverSetOptionsUpdatesEnabledState() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0,
            enabled: false
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)

        #expect(observer.isEnabled() == false)
        #expect(observer.options.enabled == false)

        // Update options to enable the query
        let enabledOptions = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0,
            enabled: true
        )

        observer.setOptions(enabledOptions)
        #expect(observer.isEnabled() == true)
        #expect(observer.options.enabled == true)
    }

    @Test("InfiniteQueryObserver fetchNextPage returns task")
    func infiniteQueryObserverFetchNextPageReturnsTask() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)

        // fetchNextPage should return a task successfully
        let fetchTask = observer.fetchNextPage()
        _ = fetchTask // Verify method executes without error
    }

    @Test("InfiniteQueryObserver fetchPreviousPage returns task")
    func infiniteQueryObserverFetchPreviousPageReturnsTask() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getPreviousPageParam: { pages in
                return pages.first?.nextCursor // Simplified logic for testing
            },
            initialPageParam: 0
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)

        // fetchPreviousPage should return a task successfully
        let fetchTask = observer.fetchPreviousPage()
        _ = fetchTask // Verify method executes without error
    }

    @Test("InfiniteQueryObserver AnyQueryObserver protocol methods")
    func infiniteQueryObserverAnyQueryObserverProtocolMethods() throws {
        let queryClient = QueryClient()
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let observer = InfiniteQueryObserver(client: queryClient, options: options)
        let anyObserver: AnyQueryObserver = observer

        // Test AnyQueryObserver methods
        #expect(anyObserver.id == observer.id)
        #expect(anyObserver.isEnabled() == observer.isEnabled())

        let result = anyObserver.getCurrentResult()
        #expect(result.isStale == observer.isStale)
    }
}

// MARK: - InfiniteQueryObserverResult Tests

@Suite("InfiniteQueryObserverResult Tests")
@MainActor
struct InfiniteQueryObserverResultTests {
    @Test("InfiniteQueryObserverResult initializes with QueryState")
    func infiniteQueryObserverResultInitializesWithQueryState() throws {
        let infiniteData = InfiniteData<PostPage, Int>(
            pages: [PostPage.create(start: 0, count: 10)],
            pageParams: [0]
        )

        let queryState = QueryState<InfiniteData<PostPage, Int>>(
            data: infiniteData,
            status: .success
        )

        let result = InfiniteQueryObserverResult<PostPage, Int>(
            queryState: queryState,
            isStale: false,
            hasNextPage: true,
            hasPreviousPage: false
        )

        #expect(result.data?.pages.count == infiniteData.pages.count)
        #expect(result.isSuccess == true)
        #expect(result.isStale == false)
        #expect(result.hasNextPage == true)
        #expect(result.hasPreviousPage == false)
    }

    @Test("InfiniteQueryObserverResult data properties from QueryState")
    func infiniteQueryObserverResultDataPropertiesFromQueryState() throws {
        let infiniteData = InfiniteData<PostPage, Int>(
            pages: [PostPage.create(start: 0, count: 10)],
            pageParams: [0]
        )

        let queryState = QueryState<InfiniteData<PostPage, Int>>(
            data: infiniteData,
            dataUpdateCount: 1,
            error: nil,
            errorUpdateCount: 0,
            status: .success,
            fetchStatus: .idle
        )

        let result = InfiniteQueryObserverResult<PostPage, Int>(
            queryState: queryState,
            isStale: false
        )

        #expect(result.data?.pages.count == infiniteData.pages.count)
        #expect(result.dataUpdateCount == 1)
        #expect(result.errorUpdateCount == 0)
        #expect(result.error == nil)
    }

    @Test("InfiniteQueryObserverResult fetch status properties")
    func infiniteQueryObserverResultFetchStatusProperties() throws {
        let queryState = QueryState<InfiniteData<PostPage, Int>>(
            status: .pending,
            fetchStatus: .fetching
        )

        let result = InfiniteQueryObserverResult<PostPage, Int>(
            queryState: queryState,
            isStale: true,
            isFetchingNextPage: true
        )

        #expect(result.isFetching == true)
        #expect(result.isPending == true)
        #expect(result.isLoading == true) // pending + fetching
        #expect(result.isRefetching == false) // not refetching since pending
        #expect(result.isFetchingNextPage == true)
        #expect(result.isFetchingPreviousPage == false)
    }

    @Test("InfiniteQueryObserverResult pagination properties")
    func infiniteQueryObserverResultPaginationProperties() throws {
        let queryState = QueryState<InfiniteData<PostPage, Int>>(
            status: .success
        )

        let result = InfiniteQueryObserverResult<PostPage, Int>(
            queryState: queryState,
            isStale: false,
            hasNextPage: true,
            hasPreviousPage: false,
            isFetchingNextPage: false,
            isFetchingPreviousPage: false,
            isFetchNextPageError: false,
            isFetchPreviousPageError: false
        )

        #expect(result.hasNextPage == true)
        #expect(result.hasPreviousPage == false)
        #expect(result.isFetchingNextPage == false)
        #expect(result.isFetchingPreviousPage == false)
        #expect(result.isFetchNextPageError == false)
        #expect(result.isFetchPreviousPageError == false)
    }
}

// MARK: - InfiniteQuery Tests

@Suite("InfiniteQuery Tests")
@MainActor
struct InfiniteQueryTests {
    @Test("InfiniteQuery hasNextPage with getNextPageParam")
    func infiniteQueryHasNextPageWithGetNextPageParam() throws {
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let config = InfiniteQueryConfig<PostPage, String, Int>(
            queryKey: "posts",
            queryHash: "posts",
            options: options
        )

        let queryCache = QueryCache()
        let infiniteQuery = InfiniteQuery<PostPage, String, Int>(config: config, cache: queryCache)

        // Initially should have no pages, so hasNextPage should be false (no data to evaluate)
        #expect(infiniteQuery.hasNextPage() == false)

        // Set some data manually for testing
        let testData = InfiniteData<PostPage, Int>(
            pages: [PostPage.create(start: 0, count: 10)],
            pageParams: [0]
        )
        infiniteQuery.setData(testData)

        // Now should have next page since the created page has nextCursor
        #expect(infiniteQuery.hasNextPage() == true)
    }

    @Test("InfiniteQuery hasPreviousPage with getPreviousPageParam")
    func infiniteQueryHasPreviousPageWithGetPreviousPageParam() throws {
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getPreviousPageParam: { pages in
                return pages.first?.nextCursor // Simplified logic for testing
            },
            initialPageParam: 0
        )

        let config = InfiniteQueryConfig<PostPage, String, Int>(
            queryKey: "posts",
            queryHash: "posts",
            options: options
        )

        let queryCache = QueryCache()
        let infiniteQuery = InfiniteQuery<PostPage, String, Int>(config: config, cache: queryCache)

        // Initially should have no pages, so hasPreviousPage should be false
        #expect(infiniteQuery.hasPreviousPage() == false)

        // Set some data manually for testing
        let testData = InfiniteData<PostPage, Int>(
            pages: [PostPage.create(start: 10, count: 10)],
            pageParams: [10]
        )
        infiniteQuery.setData(testData)

        // Now should have previous page based on our simplified logic
        #expect(infiniteQuery.hasPreviousPage() == true)
    }

    @Test("InfiniteQuery fetchDirection property")
    func infiniteQueryFetchDirectionProperty() throws {
        let options = InfiniteQueryOptions<PostPage, QueryError, String, Int>(
            queryKey: "posts",
            queryFn: { _, cursor in
                return PostPage.create(start: cursor ?? 0, count: 10)
            },
            getNextPageParam: { pages in
                return pages.last?.nextCursor
            },
            initialPageParam: 0
        )

        let config = InfiniteQueryConfig<PostPage, String, Int>(
            queryKey: "posts",
            queryHash: "posts",
            options: options
        )

        let queryCache = QueryCache()
        let infiniteQuery = InfiniteQuery<PostPage, String, Int>(config: config, cache: queryCache)

        // Initially should have no fetch direction
        #expect(infiniteQuery.fetchDirection == nil)

        // The fetchDirection would be set during actual fetch operations
        // This test verifies the property is accessible
    }
}
