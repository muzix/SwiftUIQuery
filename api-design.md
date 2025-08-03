# SwiftUI Query - API Design

This document defines the API design for SwiftUI Query, focusing on the useQuery clone implementation.

## useQuery API Clone - Design Exploration

### Current useQuery in React
```javascript
const { data, isLoading, error, refetch } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId),
  staleTime: 5 * 60 * 1000,
  gcTime: 10 * 60 * 1000,
  refetchOnWindowFocus: true,
  retry: 3,
  enabled: !!userId,
  select: (data) => data.profile,
  placeholderData: previousData => previousData,
  initialData: cachedUser,
  throwOnError: false,
  refetchInterval: 30000,
  refetchIntervalInBackground: false,
  refetchOnAppear: true,
  refetchOnReconnect: true,
  notifyOnChangeProps: ['data', 'error'],
  meta: { source: 'userProfile' }
})
```

### How caching works in details of React useQuery

#### Cache Key Structure
- Query keys are hashed using JSON.stringify with sorted object keys for consistent hashing
- The hash serves as the unique identifier in QueryCache Map
- Supports arrays, objects, primitives - anything JSON serializable

#### Stale-While-Revalidate Strategy
- **Default behavior**: Queries are stale immediately after fetching (staleTime: 0)
- Shows cached data immediately while refetching in background
- Three states: fresh (within staleTime), stale (beyond staleTime), or static (never stale)
- Stale calculation: `isStale = (Date.now() - dataUpdatedAt) > staleTime`

#### Cache Persistence & Garbage Collection
- Queries remain in cache even when all observers unmount
- Garbage collection triggers after `gcTime` (default 5 minutes) of inactivity
- Cache entries removed when no observers and fetchStatus is 'idle'

#### Structural Sharing
- Prevents unnecessary re-renders by maintaining referential equality
- Recursively compares old and new data, returns old reference if unchanged
- Only creates new objects/arrays for changed portions
- Can be disabled or customized via options

### How caching works in details of React useInfiniteQuery

#### Page Storage Structure
```typescript
InfiniteData<T> = {
  pages: T[],        // Array of page data
  pageParams: unknown[] // Corresponding page parameters
}
```

#### Page Fetching Logic
- **Initial page**: Uses `initialPageParam` for first fetch
- **Next page**: Determined by `getNextPageParam(lastPage, allPages, lastPageParam, allPageParams)`
- **Previous page**: Determined by `getPreviousPageParam(firstPage, allPages, firstPageParam, allPageParams)`
- Fetching stops when page param functions return `null` or `undefined`

#### Page Direction Management
- `fetchNextPage()` adds pages to end of array (forward direction)
- `fetchPreviousPage()` adds pages to beginning of array (backward direction)
- Optional `maxPages` limit with automatic page removal based on direction

### Key Behaviors to Implement for UseQuery and UseInfiniteQuery

1. **Page Management** (InfiniteQuery specific)
   - Store pages as ordered array with corresponding pageParams
   - Support bi-directional fetching (next/previous)
   - Implement page limit with intelligent removal strategy
   - Maintain page fetch direction in query metadata

2. **State Isolation**
   - Each unique query key creates separate Query instance
   - Queries with same queryFn but different keys have isolated state
   - Multiple observers can share same query via key
   - Updates broadcast to all observers of same query

3. **Refetch Behavior** (iOS/SwiftUI Terminology)
   - **On Appear**: Three modes - always, ifStale, or never refetch when SwiftUI view appears (`.onAppear`)
   - **On Key Change**: Automatically switch to new query, show cached data immediately, refetch if stale/missing
   - **On App Foreground**: Refetch stale queries when app becomes active from background (UIApplication notifications)
   - **On Network Reconnect**: Refetch stale queries when network connectivity is restored (Network framework)
   - **Interval**: Optional periodic refetching
   - **Manual**: Via refetch() function
   - All refetches respect enabled state and stale conditions

4. **Page Determination** (InfiniteQuery specific)
   - `getNextPageParam` determines next page parameter from current data
   - `getPreviousPageParam` determines previous page parameter
   - Return `null`/`undefined` to signal no more pages
   - Page params stored alongside page data for consistency

5. **Concurrency & Memory**
   - Fetch deduplication: Multiple observers share same fetch promise
   - Background refetching for stale data
   - Automatic retry with exponential backoff for failures
   - Garbage collection for inactive queries
   - Structural sharing to minimize memory usage

### SwiftUI API Design

#### Dependencies

This implementation requires the Perception library for iOS 16 compatibility:

**Package.swift dependency:**
```swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.0.0")
]
```

**Import statements:**
```swift
import SwiftUI
import Perception

// For iOS 16 compatibility, we use Perception as a drop-in replacement for @Observable
// Perception provides the @Perceptible macro which backports @Observable to iOS 16
// WithPerceptionTracking wrapper ensures proper state tracking in SwiftUI views
```

#### QueryKey

Query key is simply anything which conform to QueryKey protocol

```swift
struct Query<Data> {

    private let key: QueryKey
}

protocol QueryKey: Hashable {}

enum CustomQueryKey: QueryKey {
    case fetchUser(userId: String)
}
```

#### Components/Classes/Structs to be implemented

### UseQuery

```swift
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct UseQuery<Key: QueryKey, Data: Sendable, Content: View>: View {
    let key: Key
    let queryFn: @Sendable () async throws -> Data
    let staleTime: TimeInterval
    let gcTime: TimeInterval
    let refetchOnAppForeground: Bool
    let refetchOnNetworkReconnect: Bool
    let refetchOnAppear: RefetchOnAppear
    let retry: RetryConfig
    let retryDelay: RetryDelayFunction?
    let enabled: Bool
    let refetchInterval: TimeInterval?
    let refetchIntervalInBackground: Bool
    let select: (@Sendable (Data) -> Data)?
    let placeholderData: (@Sendable (Data?) -> Data)?
    let initialData: Data?
    let initialDataUpdatedAt: Date?
    let throwOnError: Bool
    let meta: QueryMeta?
    
    @State private var queryObserver: QueryObserver<Key, Data>
    @ViewBuilder private var content: (QueryObserver<Key, Data>) -> Content
    
    init(
        key: Key,
        queryFn: @escaping @Sendable () async throws -> Data,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = 5 * 60, // 5 minutes
        refetchOnAppForeground: Bool = true,
        refetchOnNetworkReconnect: Bool = true,
        refetchOnAppear: RefetchOnAppear = .always,
        retry: RetryConfig = .default,
        retryDelay: RetryDelayFunction? = nil,
        enabled: Bool = true,
        refetchInterval: TimeInterval? = nil,
        refetchIntervalInBackground: Bool = false,
        select: (@Sendable (Data) -> Data)? = nil,
        placeholderData: (@Sendable (Data?) -> Data)? = nil,
        initialData: Data? = nil,
        initialDataUpdatedAt: Date? = nil,
        throwOnError: Bool = false,
        meta: QueryMeta? = nil,
        @ViewBuilder content: @escaping (QueryObserver<Key, Data>) -> Content
    ) {
        self.key = key
        self.queryFn = queryFn
        self.staleTime = staleTime
        self.gcTime = gcTime
        self.refetchOnAppForeground = refetchOnAppForeground
        self.refetchOnNetworkReconnect = refetchOnNetworkReconnect
        self.refetchOnAppear = refetchOnAppear
        self.retry = retry
        self.retryDelay = retryDelay
        self.enabled = enabled
        self.refetchInterval = refetchInterval
        self.refetchIntervalInBackground = refetchIntervalInBackground
        self.select = select
        self.placeholderData = placeholderData
        self.initialData = initialData
        self.initialDataUpdatedAt = initialDataUpdatedAt
        self.throwOnError = throwOnError
        self.meta = meta
        self.content = content
        
        // Initialize QueryObserver with default client (will be updated in body using Environment)
        let client = QueryClientProvider.shared.queryClient
        let options = QueryOptions(
            queryKey: key,
            queryFn: queryFn,
            staleTime: staleTime,
            gcTime: gcTime,
            refetchOnWindowFocus: refetchOnWindowFocus,
            refetchOnReconnect: refetchOnReconnect,
            refetchOnAppear: refetchOnAppear,
            retry: retry,
            retryDelay: retryDelay,
            enabled: enabled,
            refetchInterval: refetchInterval,
            refetchIntervalInBackground: refetchIntervalInBackground,
            select: select,
            placeholderData: placeholderData,
            initialData: initialData,
            initialDataUpdatedAt: initialDataUpdatedAt,
            throwOnError: throwOnError,
            meta: meta
        )
        self._queryObserver = State(initialValue: QueryObserver(client: client, options: options))
    }
    
    var body: some View {
        WithPerceptionTracking {
            content(queryObserver)
        }
        .task {
            // Subscribe to query
            await queryObserver.subscribe()
        }
        .onChange(of: key) { _, newKey in
            // When queryKey changes, automatically switch to new query and refetch if needed
            // This matches React Query behavior: show cached data immediately, fetch if stale/missing
            Task {
                await queryObserver.setOptions(QueryOptions(
                    queryKey: newKey,
                    queryFn: queryFn,
                    staleTime: staleTime,
                    gcTime: gcTime,
                    refetchOnAppForeground: refetchOnAppForeground,
                    refetchOnNetworkReconnect: refetchOnNetworkReconnect,
                    refetchOnAppear: refetchOnAppear,
                    retry: retry,
                    retryDelay: retryDelay,
                    enabled: enabled,
                    refetchInterval: refetchInterval,
                    refetchIntervalInBackground: refetchIntervalInBackground,
                    select: select,
                    placeholderData: placeholderData,
                    initialData: initialData,
                    initialDataUpdatedAt: initialDataUpdatedAt,
                    throwOnError: throwOnError,
                    meta: meta
                ))
            }
        }
        .onDisappear {
            Task {
                await queryObserver.unsubscribe()
            }
        }
    }
}
```

### UseInfiniteQuery

```swift
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct UseInfiniteQuery<Key: QueryKey, Data: Sendable, PageParam: Sendable, Content: View>: View {
    let key: Key
    let queryFn: @Sendable (PageParam) async throws -> Data
    let initialPageParam: PageParam
    let getNextPageParam: @Sendable (Data, [Data], PageParam, [PageParam]) -> PageParam?
    let getPreviousPageParam: (@Sendable (Data, [Data], PageParam, [PageParam]) -> PageParam?)?
    let maxPages: Int?
    let staleTime: TimeInterval
    let gcTime: TimeInterval
    let refetchOnAppForeground: Bool
    let refetchOnNetworkReconnect: Bool
    let refetchOnAppear: RefetchOnAppear
    let retry: RetryConfig
    let retryDelay: RetryDelayFunction?
    let enabled: Bool
    let refetchInterval: TimeInterval?
    let refetchIntervalInBackground: Bool
    let select: (@Sendable (InfiniteData<Data, PageParam>) -> InfiniteData<Data, PageParam>)?
    let placeholderData: (@Sendable (InfiniteData<Data, PageParam>?) -> InfiniteData<Data, PageParam>)?
    let initialData: InfiniteData<Data, PageParam>?
    let initialDataUpdatedAt: Date?
    let throwOnError: Bool
    let meta: QueryMeta?
    
    @State private var infiniteQueryObserver: InfiniteQueryObserver<Key, Data, PageParam>
    @ViewBuilder private var content: (InfiniteQueryObserver<Key, Data, PageParam>) -> Content
    
    init(
        key: Key,
        queryFn: @escaping @Sendable (PageParam) async throws -> Data,
        initialPageParam: PageParam,
        getNextPageParam: @escaping @Sendable (Data, [Data], PageParam, [PageParam]) -> PageParam?,
        getPreviousPageParam: (@Sendable (Data, [Data], PageParam, [PageParam]) -> PageParam?)? = nil,
        maxPages: Int? = nil,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = 5 * 60, // 5 minutes
        refetchOnAppForeground: Bool = true,
        refetchOnNetworkReconnect: Bool = true,
        refetchOnAppear: RefetchOnAppear = .always,
        retry: RetryConfig = .default,
        retryDelay: RetryDelayFunction? = nil,
        enabled: Bool = true,
        refetchInterval: TimeInterval? = nil,
        refetchIntervalInBackground: Bool = false,
        select: (@Sendable (InfiniteData<Data, PageParam>) -> InfiniteData<Data, PageParam>)? = nil,
        placeholderData: (@Sendable (InfiniteData<Data, PageParam>?) -> InfiniteData<Data, PageParam>)? = nil,
        initialData: InfiniteData<Data, PageParam>? = nil,
        initialDataUpdatedAt: Date? = nil,
        throwOnError: Bool = false,
        meta: QueryMeta? = nil,
        @ViewBuilder content: @escaping (InfiniteQueryObserver<Key, Data, PageParam>) -> Content
    ) {
        self.key = key
        self.queryFn = queryFn
        self.initialPageParam = initialPageParam
        self.getNextPageParam = getNextPageParam
        self.getPreviousPageParam = getPreviousPageParam
        self.maxPages = maxPages
        self.staleTime = staleTime
        self.gcTime = gcTime
        self.refetchOnAppForeground = refetchOnAppForeground
        self.refetchOnNetworkReconnect = refetchOnNetworkReconnect
        self.refetchOnAppear = refetchOnAppear
        self.retry = retry
        self.retryDelay = retryDelay
        self.enabled = enabled
        self.refetchInterval = refetchInterval
        self.refetchIntervalInBackground = refetchIntervalInBackground
        self.select = select
        self.placeholderData = placeholderData
        self.initialData = initialData
        self.initialDataUpdatedAt = initialDataUpdatedAt
        self.throwOnError = throwOnError
        self.meta = meta
        self.content = content
        
        // Initialize InfiniteQueryObserver with default client (will be updated in body using Environment)
        let client = QueryClientProvider.shared.queryClient
        let options = InfiniteQueryOptions(
            queryKey: key,
            queryFn: queryFn,
            initialPageParam: initialPageParam,
            getNextPageParam: getNextPageParam,
            getPreviousPageParam: getPreviousPageParam,
            maxPages: maxPages,
            staleTime: staleTime,
            gcTime: gcTime,
            refetchOnWindowFocus: refetchOnWindowFocus,
            refetchOnReconnect: refetchOnReconnect,
            refetchOnAppear: refetchOnAppear,
            retry: retry,
            retryDelay: retryDelay,
            enabled: enabled,
            refetchInterval: refetchInterval,
            refetchIntervalInBackground: refetchIntervalInBackground,
            select: select,
            placeholderData: placeholderData,
            initialData: initialData,
            initialDataUpdatedAt: initialDataUpdatedAt,
            throwOnError: throwOnError,
            meta: meta
        )
        self._infiniteQueryObserver = State(initialValue: InfiniteQueryObserver(client: client, options: options))
    }
    
    var body: some View {
        WithPerceptionTracking {
            content(infiniteQueryObserver)
        }
        .task {
            // Subscribe to infinite query
            await infiniteQueryObserver.subscribe()
        }
        .onChange(of: key) { _, newKey in
            // When queryKey changes, automatically switch to new query and refetch if needed
            // This matches React Query behavior: show cached data immediately, fetch if stale/missing
            Task {
                await infiniteQueryObserver.setOptions(InfiniteQueryOptions(
                    queryKey: newKey,
                    queryFn: queryFn,
                    initialPageParam: initialPageParam,
                    getNextPageParam: getNextPageParam,
                    getPreviousPageParam: getPreviousPageParam,
                    maxPages: maxPages,
                    staleTime: staleTime,
                    gcTime: gcTime,
                    refetchOnAppForeground: refetchOnAppForeground,
                    refetchOnNetworkReconnect: refetchOnNetworkReconnect,
                    refetchOnAppear: refetchOnAppear,
                    retry: retry,
                    retryDelay: retryDelay,
                    enabled: enabled,
                    refetchInterval: refetchInterval,
                    refetchIntervalInBackground: refetchIntervalInBackground,
                    select: select,
                    placeholderData: placeholderData,
                    initialData: initialData,
                    initialDataUpdatedAt: initialDataUpdatedAt,
                    throwOnError: throwOnError,
                    meta: meta
                ))
            }
        }
        .onDisappear {
            Task {
                await infiniteQueryObserver.unsubscribe()
            }
        }
    }
}
```

### Core Components

#### Supporting Types

```swift
// Query Key Protocol
protocol QueryKey: Hashable, Sendable {}

// Retry Configuration
enum RetryConfig: Sendable {
    case none
    case fixed(count: Int)
    case exponentialBackoff(maxAttempts: Int, initialInterval: TimeInterval, maxInterval: TimeInterval)
    case custom(@Sendable (Int, Error) -> Bool)
    
    static var `default`: RetryConfig {
        .exponentialBackoff(maxAttempts: 3, initialInterval: 1.0, maxInterval: 30.0)
    }
}

// Retry Delay Function
typealias RetryDelayFunction = @Sendable (Int, Error) -> TimeInterval

// Refetch on Appear Options (iOS/SwiftUI equivalent of refetchOnMount)
enum RefetchOnAppear: Sendable {
    case always      // Always refetch when view appears
    case ifStale     // Only refetch if data is stale when view appears
    case never       // Never automatically refetch on view appear
}

// Query Meta
struct QueryMeta: Sendable {
    let data: [String: Any]
}

// Query Options
struct QueryOptions<Key: QueryKey, TData: Sendable>: Sendable {
    let queryKey: Key
    let queryFn: @Sendable () async throws -> TData
    let staleTime: TimeInterval
    let gcTime: TimeInterval
    let refetchOnAppForeground: Bool
    let refetchOnNetworkReconnect: Bool
    let refetchOnAppear: RefetchOnAppear
    let retry: RetryConfig
    let retryDelay: RetryDelayFunction?
    let enabled: Bool
    let refetchInterval: TimeInterval?
    let refetchIntervalInBackground: Bool
    let select: (@Sendable (TData) -> TData)?
    let placeholderData: (@Sendable (TData?) -> TData)?
    let initialData: TData?
    let initialDataUpdatedAt: Date?
    let throwOnError: Bool
    let meta: QueryMeta?
}

// Infinite Query Options
struct InfiniteQueryOptions<Key: QueryKey, TData: Sendable, TPageParam: Sendable>: Sendable {
    let queryKey: Key
    let queryFn: @Sendable (TPageParam) async throws -> TData
    let initialPageParam: TPageParam
    let getNextPageParam: @Sendable (TData, [TData], TPageParam, [TPageParam]) -> TPageParam?
    let getPreviousPageParam: (@Sendable (TData, [TData], TPageParam, [TPageParam]) -> TPageParam?)?
    let maxPages: Int?
    let staleTime: TimeInterval
    let gcTime: TimeInterval
    let refetchOnAppForeground: Bool
    let refetchOnNetworkReconnect: Bool
    let refetchOnAppear: RefetchOnAppear
    let retry: RetryConfig
    let retryDelay: RetryDelayFunction?
    let enabled: Bool
    let refetchInterval: TimeInterval?
    let refetchIntervalInBackground: Bool
    let select: (@Sendable (InfiniteData<TData, TPageParam>) -> InfiniteData<TData, TPageParam>)?
    let placeholderData: (@Sendable (InfiniteData<TData, TPageParam>?) -> InfiniteData<TData, TPageParam>)?
    let initialData: InfiniteData<TData, TPageParam>?
    let initialDataUpdatedAt: Date?
    let throwOnError: Bool
    let meta: QueryMeta?
}

// Infinite Query Data Structure
struct InfiniteData<TData: Sendable, TPageParam: Sendable>: Sendable {
    let pages: [TData]
    let pageParams: [TPageParam]
}

// Query State
enum QueryState<TData: Sendable, TError: Error>: Sendable {
    case idle
    case loading
    case error(TError)
    case success(TData)
}

// Fetch Status
enum FetchStatus: Sendable {
    case idle
    case fetching
    case paused
}
```

#### QueryClientProvider

```swift
// Query Client Provider for dependency injection
@Perceptible
final class QueryClientProvider: Sendable {
    static let shared = QueryClientProvider()
    let queryClient: QueryClient
    
    private init() {
        self.queryClient = QueryClient()
    }
}

// SwiftUI Environment Key
struct QueryClientKey: EnvironmentKey {
    static let defaultValue = QueryClientProvider.shared.queryClient
}

extension EnvironmentValues {
    var queryClient: QueryClient {
        get { self[QueryClientKey.self] }
        set { self[QueryClientKey.self] = newValue }
    }
}

// Provider View for SwiftUI
struct QueryClientProviderView<Content: View>: View {
    let queryClient: QueryClient
    let content: Content
    
    init(queryClient: QueryClient = QueryClient(), @ViewBuilder content: () -> Content) {
        self.queryClient = queryClient
        self.content = content()
    }
    
    var body: some View {
        content
            .environment(\.queryClient, queryClient)
    }
}
```

#### QueryClient

```swift
@Perceptible
final class QueryClient: Sendable {
    let queryCache: QueryCache
    let mutationCache: MutationCache
    let defaultOptions: DefaultOptions
    
    init(
        queryCache: QueryCache? = nil,
        mutationCache: MutationCache? = nil,
        defaultOptions: DefaultOptions = DefaultOptions()
    ) {
        self.queryCache = queryCache ?? QueryCache()
        self.mutationCache = mutationCache ?? MutationCache()
        self.defaultOptions = defaultOptions
    }
    
    // Query Management
    func getQuery<Key: QueryKey, TData: Sendable>(
        key: Key
    ) -> Query<Key, TData>? {
        queryCache.find(key: key)
    }
    
    func ensureQuery<Key: QueryKey, TData: Sendable>(
        options: QueryOptions<Key, TData>
    ) -> Query<Key, TData> {
        let query = queryCache.build(client: self, options: options)
        query.initialize()
        return query
    }
    
    // Query Invalidation
    func invalidateQueries<Key: QueryKey>(
        key: Key? = nil,
        exact: Bool = false,
        refetch: Bool = true
    ) async {
        await queryCache.invalidate(key: key, exact: exact, refetch: refetch)
    }
    
    // Query Refetching
    func refetchQueries<Key: QueryKey>(
        key: Key? = nil,
        exact: Bool = false
    ) async {
        await queryCache.refetch(key: key, exact: exact)
    }
    
    // Query Data Management
    func setQueryData<Key: QueryKey, TData: Sendable>(
        key: Key,
        data: TData,
        updatedAt: Date = Date()
    ) {
        let query = ensureQuery(options: QueryOptions(
            queryKey: key,
            queryFn: { data } // Dummy function
        ))
        query.setData(data: data, updatedAt: updatedAt)
    }
    
    func getQueryData<Key: QueryKey, TData: Sendable>(
        key: Key
    ) -> TData? {
        getQuery(key: key)?.state.data
    }
    
    // Cache Management
    func clear() {
        queryCache.clear()
        mutationCache.clear()
    }
}
```

#### QueryCache

**Note**: QueryCache does NOT use `@Perceptible` as it's an internal storage mechanism not directly observed by SwiftUI views. Reactive updates flow through QueryObserver instances instead.

**Note**: QueryCache currently uses `@MainActor` because the `AnyQuery` protocol is `@MainActor`. In an ideal architecture, QueryCache would be thread-safe using an actor-based design, but this requires refactoring the entire type system.

## Why QueryCache is annotated with @MainActor

The `@MainActor` annotation on `QueryCache` is **not ideal** and exists due to current architectural constraints rather than by design choice.

### Current Reality (Why @MainActor is needed now):

1. **AnyQuery Protocol Constraint**: The `AnyQuery` protocol is marked `@MainActor`, requiring all conforming types and their consumers to run on the main thread.

2. **Type System Dependencies**: Since QueryCache stores and manipulates `AnyQuery` instances, accessing properties like `query.queryHash` requires main actor isolation, forcing QueryCache to also be `@MainActor`.

3. **Sendable Conflicts**: Without `@MainActor`, making QueryCache `Sendable` would require:
   - Making all stored properties immutable or thread-safe
   - Using actors or proper synchronization primitives  
   - Refactoring the entire query type hierarchy

### Ideal Architecture (What it should be):

Looking at TanStack Query's original design, `QueryCache` should be thread-safe storage without main actor constraints:

```swift
// Ideal: Thread-safe storage without main actor constraint
actor QueryCacheStorage {
    private var queries: [String: AnyQuery] = [:]
    // ... thread-safe operations
}

// No @MainActor needed - just a coordination layer
public final class QueryCache {
    private let storage = QueryCacheStorage()
    // ... public API that delegates to actor
}
```

### The Trade-off:

- **Current approach**: Simple to implement, works correctly, but forces cache operations to main thread
- **Ideal approach**: Better performance, matches TanStack Query architecture, but requires significant refactoring

### Performance Impact:

In practice, the performance impact is minimal because:
- Cache operations are typically fast (dictionary lookups)
- Most query operations already happen on the main thread via QueryObserver
- The bottleneck is usually network requests, not cache access

### Future Refactoring Path:

The `@MainActor` annotation is a **necessary compromise** given the current type system design. It ensures thread safety and Swift 6 compliance while maintaining a working implementation that matches TanStack Query's behavior.

To remove `@MainActor` from QueryCache in the future, we would need to:
1. Make `AnyQuery` not require main actor isolation
2. Use actor-based storage for thread safety
3. Restructure the type hierarchy to be more concurrent-friendly

For now, the documentation correctly notes this as a current limitation rather than an intended design choice.

```swift
// Note: No @Perceptible annotation - QueryCache is internal storage, not directly observable
// @MainActor currently required due to AnyQuery protocol constraint
@MainActor
final class QueryCache {
    private let queries = NSCache<NSString, AnyQuery>()
    private let queriesMap = Mutex<[String: AnyQuery]>()
    
    func find<Key: QueryKey, TData: Sendable>(
        key: Key
    ) -> Query<Key, TData>? {
        let hashKey = hashQueryKey(key)
        return queriesMap.withLock { map in
            map[hashKey] as? Query<Key, TData>
        }
    }
    
    func build<Key: QueryKey, TData: Sendable>(
        client: QueryClient,
        options: QueryOptions<Key, TData>
    ) -> Query<Key, TData> {
        let hashKey = hashQueryKey(options.queryKey)
        
        return queriesMap.withLock { map in
            if let existing = map[hashKey] as? Query<Key, TData> {
                return existing
            }
            
            let query = Query(
                key: options.queryKey,
                client: client,
                options: options,
                cache: self,
                state: QueryState<TData, Error>.idle
            )
            
            map[hashKey] = query
            return query
        }
    }
    
    func remove<Key: QueryKey>(_ key: Key) {
        let hashKey = hashQueryKey(key)
        queriesMap.withLock { map in
            map.removeValue(forKey: hashKey)
        }
    }
    
    func clear() {
        queriesMap.withLock { map in
            map.removeAll()
        }
    }
    
    private func hashQueryKey<Key: QueryKey>(_ key: Key) -> String {
        // Implementation for consistent hashing of query keys
        var hasher = Hasher()
        key.hash(into: &hasher)
        return String(hasher.finalize())
    }
}
```

#### Query

```swift
@Perceptible
final class Query<Key: QueryKey, TData: Sendable>: Sendable {
    let queryKey: Key
    let queryHash: String
    private(set) var state: QueryState<TData, Error>
    private(set) var fetchStatus: FetchStatus = .idle
    private(set) var dataUpdatedAt: Date?
    private(set) var errorUpdatedAt: Date?
    
    private let client: QueryClient
    private let options: QueryOptions<Key, TData>
    private let cache: QueryCache
    private var observers = Set<QueryObserverIdentifier>()
    private var gcTimer: Timer?
    private var refetchTimer: Timer?
    private var currentPromise: Task<TData, Error>?
    
    init(
        key: Key,
        client: QueryClient,
        options: QueryOptions<Key, TData>,
        cache: QueryCache,
        state: QueryState<TData, Error>
    ) {
        self.queryKey = key
        self.queryHash = String(key.hashValue)
        self.client = client
        self.options = options
        self.cache = cache
        self.state = state
    }
    
    func initialize() {
        // Set initial data if provided
        if let initialData = options.initialData {
            setData(data: initialData, updatedAt: options.initialDataUpdatedAt ?? Date())
        }
        
        // Set up refetch timer if configured
        updateRefetchTimer()
    }
    
    func addObserver(_ identifier: QueryObserverIdentifier) {
        observers.insert(identifier)
        gcTimer?.invalidate()
        gcTimer = nil
    }
    
    func removeObserver(_ identifier: QueryObserverIdentifier) {
        observers.remove(identifier)
        
        if observers.isEmpty {
            scheduleGarbageCollection()
        }
    }
    
    func fetch() async throws -> TData {
        // Check if we already have a fetch in progress
        if let promise = currentPromise {
            return try await promise.value
        }
        
        // Check if query is enabled
        guard options.enabled else {
            throw QueryError.disabled
        }
        
        // Create new fetch promise
        let promise = Task<TData, Error> {
            fetchStatus = .fetching
            
            do {
                let data = try await options.queryFn()
                setData(data: data, updatedAt: Date())
                return data
            } catch {
                setError(error: error, updatedAt: Date())
                throw error
            }
        }
        
        currentPromise = promise
        
        do {
            let result = try await promise.value
            currentPromise = nil
            fetchStatus = .idle
            return result
        } catch {
            currentPromise = nil
            fetchStatus = .idle
            throw error
        }
    }
    
    func setData(data: TData, updatedAt: Date) {
        self.state = .success(data)
        self.dataUpdatedAt = updatedAt
        self.errorUpdatedAt = nil
    }
    
    func setError(error: Error, updatedAt: Date) {
        self.state = .error(error)
        self.errorUpdatedAt = updatedAt
    }
    
    private func scheduleGarbageCollection() {
        gcTimer = Timer.scheduledTimer(
            withTimeInterval: options.gcTime,
            repeats: false
        ) { [weak self] _ in
            self?.cache.remove(self?.queryKey ?? key)
        }
    }
    
    func isStale(at date: Date = Date()) -> Bool {
        guard let dataUpdatedAt = dataUpdatedAt else { return true }
        return date.timeIntervalSince(dataUpdatedAt) > options.staleTime
    }
    
    func updateOptions(_ newOptions: QueryOptions<Key, TData>) {
        // Update query options without changing the key
        options = newOptions
        
        // Update any timers based on new options
        updateRefetchTimer()
    }
    
    private func updateRefetchTimer() {
        refetchTimer?.invalidate()
        refetchTimer = nil
        
        guard let interval = options.refetchInterval, interval > 0 else { return }
        
        refetchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                // Only refetch if enabled and in foreground (unless background refetch is enabled)
                if options.enabled && (options.refetchIntervalInBackground || !isInBackground()) {
                    try? await self.fetch()
                }
            }
        }
    }
    
    private func isInBackground() -> Bool {
        // This should be implemented based on app state
        // For now, return false (assuming foreground)
        return false
    }
}
```

#### QueryObserver

```swift
@Perceptible
final class QueryObserver<Key: QueryKey, TData: Sendable>: Sendable {
    private let client: QueryClient
    private var options: QueryOptions<Key, TData>
    private var query: Query<Key, TData>?
    private let identifier = QueryObserverIdentifier()
    
    // Observable state
    private(set) var data: TData?
    private(set) var error: Error?
    private(set) var isLoading: Bool = false
    private(set) var isFetching: Bool = false
    private(set) var isSuccess: Bool = false
    private(set) var isError: Bool = false
    private(set) var isPending: Bool = true
    private(set) var isRefetching: Bool = false
    private(set) var isStale: Bool = false
    
    init(client: QueryClient, options: QueryOptions<Key, TData>) {
        self.client = client
        self.options = options
    }
    
    func subscribe() async {
        // Get or create query
        query = client.ensureQuery(options: options)
        query?.addObserver(identifier)
        
        // Immediately update state to reflect current query state (show cached data if available)
        updateState()
        
        // Then fetch if needed (this matches React Query's behavior of showing cached data immediately)
        await executeFetch()
    }
    
    func unsubscribe() async {
        query?.removeObserver(identifier)
    }
    
    func setOptions(_ newOptions: QueryOptions<Key, TData>) async {
        let oldOptions = options
        options = newOptions
        
        // If query key changed, we need to subscribe to new query
        if oldOptions.queryKey != newOptions.queryKey {
            await unsubscribe()
            await subscribe()
        } else {
            // If only options changed (not key), update the query options
            query?.updateOptions(newOptions)
            // Re-evaluate fetch conditions with new options
            await executeFetch()
        }
    }
    
    func refetch() async throws -> TData? {
        guard let query = query else { return nil }
        return try await query.fetch()
    }
    
    private func executeFetch() async {
        guard let query = query else { return }
        
        // Determine if we should fetch based on query state and options
        let hasNoData: Bool
        switch query.state {
        case .success:
            hasNoData = false
        default:
            hasNoData = true
        }
        let isStale = query.isStale()
        
        let shouldFetch = options.enabled && (
            // Always fetch if no data exists
            hasNoData ||
            // Fetch based on refetchOnAppear setting and staleness
            (options.refetchOnAppear == .always) ||
            (options.refetchOnAppear == .ifStale && isStale)
        )
        
        if shouldFetch {
            do {
                _ = try await query.fetch()
                // Update state after fetch completes
                updateState()
            } catch {
                // Error is handled in query state, but update UI state
                updateState()
            }
        }
    }
    
    private func updateState() {
        guard let query = query else { return }
        
        switch query.state {
        case .idle:
            isPending = true
            isSuccess = false
            isError = false
            data = nil
            error = nil
        case .loading:
            isLoading = true
            isPending = false
            isSuccess = false
            isError = false
        case .success(let value):
            data = value
            error = nil
            isLoading = false
            isPending = false
            isSuccess = true
            isError = false
        case .error(let err):
            error = err
            data = nil
            isLoading = false
            isPending = false
            isSuccess = false
            isError = true
        }
        
        isFetching = query.fetchStatus == .fetching
        isRefetching = isFetching && !isPending
        isStale = query.isStale()
    }
}

// Supporting Types
struct QueryObserverIdentifier: Hashable, Sendable {
    let id = UUID()
}

enum QueryError: Error {
    case disabled
    case cancelled
}
```

#### InfiniteQueryObserver

```swift
@Perceptible
final class InfiniteQueryObserver<Key: QueryKey, TData: Sendable, TPageParam: Sendable>: Sendable {
    private let client: QueryClient
    private var options: InfiniteQueryOptions<Key, TData, TPageParam>
    private var query: InfiniteQuery<Key, TData, TPageParam>?
    private let identifier = QueryObserverIdentifier()
    
    // Observable state
    private(set) var data: InfiniteData<TData, TPageParam>?
    private(set) var error: Error?
    private(set) var isLoading: Bool = false
    private(set) var isFetching: Bool = false
    private(set) var isFetchingNextPage: Bool = false
    private(set) var isFetchingPreviousPage: Bool = false
    private(set) var hasNextPage: Bool = false
    private(set) var hasPreviousPage: Bool = false
    private(set) var isSuccess: Bool = false
    private(set) var isError: Bool = false
    private(set) var isPending: Bool = true
    
    init(client: QueryClient, options: InfiniteQueryOptions<Key, TData, TPageParam>) {
        self.client = client
        self.options = options
    }
    
    func fetchNextPage() async throws -> InfiniteData<TData, TPageParam>? {
        guard let query = query else { return nil }
        return try await query.fetchNextPage()
    }
    
    func fetchPreviousPage() async throws -> InfiniteData<TData, TPageParam>? {
        guard let query = query else { return nil }
        return try await query.fetchPreviousPage()
    }
    
    // Similar implementation pattern as QueryObserver
    // with additional handling for infinite pagination
}
```

### Usage Examples

#### Basic Query

```swift
import SwiftUI
import Perception

struct UserProfileView: View {
    let userId: String
    
    var body: some View {
        UseQuery(
            key: QueryKeys.user(id: userId),
            queryFn: { try await fetchUser(userId) }
        ) { observer in
            // Perception automatically tracks observer state changes
            if observer.isLoading {
                ProgressView()
            } else if let error = observer.error {
                Text("Error: \(error.localizedDescription)")
            } else if let user = observer.data {
                UserDetails(user: user)
            }
        }
    }
}

enum QueryKeys: QueryKey {
    case user(id: String)
    case posts(userId: String)
    case comments(postId: String)
}
```

#### Infinite Query

```swift
struct PostsListView: View {
    var body: some View {
        UseInfiniteQuery(
            key: QueryKeys.posts(userId: "123"),
            queryFn: { page in
                try await fetchPosts(userId: "123", page: page)
            },
            initialPageParam: 0,
            getNextPageParam: { lastPage, allPages, lastPageParam, _ in
                lastPage.hasMore ? lastPageParam + 1 : nil
            }
        ) { observer in
            ScrollView {
                LazyVStack {
                    ForEach(observer.data?.pages ?? [], id: \.self) { page in
                        ForEach(page.posts) { post in
                            PostRow(post: post)
                        }
                    }
                    
                    if observer.hasNextPage {
                        Button("Load More") {
                            Task {
                                try await observer.fetchNextPage()
                            }
                        }
                        .disabled(observer.isFetchingNextPage)
                    }
                }
            }
        }
    }
}
```

#### Manual Query Management

```swift
struct SettingsView: View {
    @EnvironmentObject var queryClient: QueryClient
    
    var body: some View {
        VStack {
            Button("Invalidate All User Queries") {
                Task {
                    await queryClient.invalidateQueries(
                        key: QueryKeys.user(id: ""),
                        exact: false
                    )
                }
            }
            
            Button("Clear Cache") {
                queryClient.clear()
            }
        }
    }
}
```

### iOS-Specific Lifecycle Monitoring

```swift
import Network
import UIKit

// App Foreground/Background Monitoring
@Perceptible
final class AppLifecycleMonitor: Sendable {
    private(set) var isAppActive: Bool = true
    
    init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppActive = true
            self?.onAppForeground?()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppActive = false
        }
    }
    
    var onAppForeground: (() -> Void)?
}

// Network Connectivity Monitoring
@Perceptible
final class NetworkMonitor: Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private(set) var isConnected: Bool = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? false
            self?.isConnected = path.status == .satisfied
            
            // Trigger reconnect callback if we just reconnected
            if !wasConnected && path.status == .satisfied {
                self?.onNetworkReconnect?()
            }
        }
        monitor.start(queue: queue)
    }
    
    var onNetworkReconnect: (() -> Void)?
}
```

### Thread Safety & Concurrency

```swift
// Thread-safe cache access using actors
actor Mutex<Value> {
    private var value: Value
    
    init(_ value: Value) {
        self.value = value
    }
    
    func withLock<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        try body(&value)
    }
}

// All public APIs are @Sendable and thread-safe
// Query state updates are synchronized
// Cache operations are protected by mutex
```
