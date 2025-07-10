# QueryClient

The central hub for managing queries, mutations, and cache operations.

## Overview

The `QueryClient` is the core of SwiftUI Query, managing all queries and mutations in your application. It handles caching, invalidation, and provides methods for programmatic query management.

## Setup

### Basic Setup

```swift
import SwiftUI
import SwiftUIQuery

@main
struct MyApp: App {
    let queryClient = QueryClient()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queryClient)
        }
    }
}
```

### Custom Configuration

```swift
let queryClient = QueryClient(
    defaultOptions: QueryClientOptions(
        queries: QueryOptions(
            staleTime: .minutes(5),
            cacheTime: .minutes(30),
            retryCount: 3,
            retryDelay: .seconds(1)
        ),
        mutations: MutationOptions(
            retryCount: 1,
            retryDelay: .seconds(2)
        )
    )
)
```

## Query Management

### Fetching Queries

```swift
@EnvironmentObject var queryClient: QueryClient

// Fetch query data
let posts = queryClient.fetchQuery(key: "posts") {
    try await fetchPosts()
}

// Fetch query with options
let user = queryClient.fetchQuery(
    key: ["user", userID],
    options: QueryOptions(staleTime: .minutes(10))
) {
    try await fetchUser(id: userID)
}
```

### Prefetching

```swift
// Prefetch data before it's needed
queryClient.prefetchQuery(key: "posts") {
    try await fetchPosts()
}

// Prefetch with conditions
if shouldPrefetchUserData {
    queryClient.prefetchQuery(key: ["user", userID]) {
        try await fetchUser(id: userID)
    }
}
```

### Query Invalidation

```swift
// Invalidate specific query
queryClient.invalidateQuery(key: "posts")

// Invalidate queries matching pattern
queryClient.invalidateQueries(matching: "user")

// Invalidate all queries
queryClient.invalidateAllQueries()
```

## Cache Management

### Get Cache Data

```swift
// Get current cache data
let cachedPosts = queryClient.getQueryData(key: "posts") as? [Post]

// Check if query exists in cache
let hasUserData = queryClient.hasQueryData(key: ["user", userID])
```

### Set Cache Data

```swift
// Set cache data directly
queryClient.setQueryData(key: "posts", data: newPosts)

// Update cache data
queryClient.setQueryData(key: "posts") { oldPosts in
    oldPosts + [newPost]
}
```

### Remove Cache Data

```swift
// Remove specific query from cache
queryClient.removeQuery(key: "posts")

// Remove queries matching pattern
queryClient.removeQueries(matching: "user")

// Clear all cache
queryClient.clear()
```

## Mutation Management

### Execute Mutations

```swift
// Execute mutation
let result = try await queryClient.mutate {
    try await createPost(post)
}

// Execute with callbacks
queryClient.mutate(
    onSuccess: { result in
        queryClient.invalidateQuery(key: "posts")
    },
    onError: { error in
        print("Mutation failed: \(error)")
    }
) {
    try await createPost(post)
}
```

## Advanced Operations

### Query Filters

```swift
// Filter queries by key pattern
let userQueries = queryClient.getQueries(matching: "user")

// Filter queries by state
let errorQueries = queryClient.getQueries(state: .error)

// Filter queries by staleness
let staleQueries = queryClient.getQueries(stale: true)
```

### Bulk Operations

```swift
// Refetch all queries
queryClient.refetchQueries()

// Refetch stale queries
queryClient.refetchQueries(stale: true)

// Refetch queries matching pattern
queryClient.refetchQueries(matching: "user")
```

### Query Cancellation

```swift
// Cancel specific query
queryClient.cancelQuery(key: "posts")

// Cancel all queries
queryClient.cancelAllQueries()
```

## Default Options

### Query Defaults

```swift
let queryClient = QueryClient(
    defaultOptions: QueryClientOptions(
        queries: QueryOptions(
            staleTime: .minutes(5),
            cacheTime: .minutes(30),
            retryCount: 3,
            retryDelay: .seconds(1),
            refetchOnMount: true,
            refetchOnWindowFocus: true,
            refetchOnReconnect: true
        )
    )
)
```

### Mutation Defaults

```swift
let queryClient = QueryClient(
    defaultOptions: QueryClientOptions(
        mutations: MutationOptions(
            retryCount: 1,
            retryDelay: .seconds(2),
            timeout: .seconds(30)
        )
    )
)
```

## State Management

### Query State

```swift
// Get query state
let queryState = queryClient.getQueryState(key: "posts")

switch queryState {
case .idle:
    print("Query not started")
case .loading:
    print("Query is loading")
case .success(let data):
    print("Query succeeded with data: \(data)")
case .error(let error):
    print("Query failed with error: \(error)")
}
```

### Cache Statistics

```swift
// Get cache statistics
let stats = queryClient.getCacheStats()
print("Total queries: \(stats.totalQueries)")
print("Active queries: \(stats.activeQueries)")
print("Stale queries: \(stats.staleQueries)")
print("Cache size: \(stats.cacheSize)")
```

## Network State Management

### Online/Offline Detection

```swift
// Check network state
let isOnline = queryClient.isOnline

// Set network state manually
queryClient.setOnline(false)

// Listen for network changes
queryClient.onNetworkChange { isOnline in
    print("Network state changed: \(isOnline)")
}
```

### Focus Management

```swift
// Check focus state
let isFocused = queryClient.isFocused

// Set focus state manually
queryClient.setFocused(true)

// Listen for focus changes
queryClient.onFocusChange { isFocused in
    print("Focus state changed: \(isFocused)")
}
```

## Error Handling

### Global Error Handling

```swift
let queryClient = QueryClient(
    defaultOptions: QueryClientOptions(
        queries: QueryOptions(
            onError: { error in
                // Handle all query errors globally
                print("Query error: \(error)")
            }
        ),
        mutations: MutationOptions(
            onError: { error in
                // Handle all mutation errors globally
                print("Mutation error: \(error)")
            }
        )
    )
)
```

### Custom Error Recovery

```swift
queryClient.setErrorRecovery { error, query in
    // Custom error recovery logic
    switch error {
    case APIError.unauthorized:
        // Redirect to login
        return .retry(after: .seconds(5))
    case APIError.serverError:
        // Retry with exponential backoff
        return .retry(after: .exponential(attempt: query.retryCount))
    default:
        return .fail
    }
}
```

## Performance Monitoring

### Query Performance

```swift
// Monitor query performance
queryClient.onQueryPerformance { metrics in
    print("Query: \(metrics.key)")
    print("Duration: \(metrics.duration)")
    print("Cache hit: \(metrics.cacheHit)")
    print("Network time: \(metrics.networkTime)")
}
```

### Memory Management

```swift
// Configure garbage collection
queryClient.configure(
    gcTime: .minutes(5),
    maxCacheSize: 100
)

// Manual garbage collection
queryClient.gc()
```

## Best Practices

1. **Create one QueryClient per app** and provide it at the root level
2. **Use environment objects** to access QueryClient in views
3. **Configure default options** that make sense for your app
4. **Implement global error handling** for consistent error management
5. **Use prefetching** for better user experience
6. **Monitor performance** in production builds
7. **Handle network state changes** appropriately
8. **Use query invalidation** to keep data fresh after mutations

## Common Patterns

### Dependency Injection

```swift
protocol QueryClientProtocol {
    func fetchQuery<T>(_ key: String, _ queryFn: @escaping () async throws -> T) -> T
    func invalidateQuery(_ key: String)
}

extension QueryClient: QueryClientProtocol {}
```

### Testing

```swift
class MockQueryClient: QueryClientProtocol {
    var mockData: [String: Any] = [:]
    
    func fetchQuery<T>(_ key: String, _ queryFn: @escaping () async throws -> T) -> T {
        return mockData[key] as! T
    }
    
    func invalidateQuery(_ key: String) {
        mockData.removeValue(forKey: key)
    }
}
```

## See Also

- <doc:Queries>
- <doc:Mutations>
- <doc:Caching>