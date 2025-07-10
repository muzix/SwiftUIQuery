# Caching

Understanding SwiftUI Query's caching strategy and optimization techniques.

## Overview

SwiftUI Query implements a sophisticated caching system based on the "stale-while-revalidate" strategy. This ensures your app feels fast and responsive while keeping data fresh.

## Cache Fundamentals

### Stale-While-Revalidate

The core caching strategy:

1. **Serve from cache** if data exists (even if stale)
2. **Fetch fresh data** in the background
3. **Update cache** when fresh data arrives
4. **Re-render components** with new data

```swift
@Query("posts", staleTime: .minutes(5)) var posts: QueryResult<[Post]>
```

### Cache Keys

Cache keys uniquely identify cached data:

```swift
// Simple string key
@Query("posts") var posts: QueryResult<[Post]>

// Hierarchical key
@Query(["user", userID, "posts"]) var userPosts: QueryResult<[Post]>

// Complex key with parameters
@Query(["posts", "filter", filter, "sort", sort]) var filteredPosts: QueryResult<[Post]>
```

## Cache Configuration

### Stale Time

How long data is considered fresh:

```swift
// Data is fresh for 5 minutes
@Query("posts", staleTime: .minutes(5)) var posts: QueryResult<[Post]>

// Data is always stale (always refetches)
@Query("posts", staleTime: .zero) var posts: QueryResult<[Post]>

// Data never goes stale
@Query("posts", staleTime: .infinity) var posts: QueryResult<[Post]>
```

### Cache Time

How long unused data stays in cache:

```swift
// Keep in cache for 30 minutes after last use
@Query("posts", cacheTime: .minutes(30)) var posts: QueryResult<[Post]>

// Remove from cache immediately when not used
@Query("posts", cacheTime: .zero) var posts: QueryResult<[Post]>

// Keep in cache forever
@Query("posts", cacheTime: .infinity) var posts: QueryResult<[Post]>
```

## Cache States

### Fresh vs Stale

```swift
@Query("posts") var posts: QueryResult<[Post]>

// Check if data is fresh
if posts.isFresh {
    // Data is within stale time
}

// Check if data is stale
if posts.isStale {
    // Data needs refetching
}
```

### Cache Hit vs Miss

```swift
@Query("posts") var posts: QueryResult<[Post]>

// First component mount - cache miss
// Data loads from network

// Second component mount - cache hit
// Data loads instantly from cache
```

## Manual Cache Management

### Setting Cache Data

```swift
@EnvironmentObject var queryClient: QueryClient

// Set cache data directly
queryClient.setQueryData(key: "posts", data: newPosts)

// Update existing cache data
queryClient.setQueryData(key: "posts") { oldPosts in
    oldPosts + [newPost]
}
```

### Getting Cache Data

```swift
// Get current cache data
let cachedPosts = queryClient.getQueryData(key: "posts") as? [Post]

// Check if data exists in cache
let hasCache = queryClient.hasQueryData(key: "posts")
```

### Removing Cache Data

```swift
// Remove specific query from cache
queryClient.removeQuery(key: "posts")

// Remove queries matching pattern
queryClient.removeQueries(matching: "user")

// Clear entire cache
queryClient.clear()
```

## Cache Invalidation

### Automatic Invalidation

Cache is automatically invalidated when:
- Mutations complete successfully
- Manual invalidation is triggered
- Cache time expires

### Manual Invalidation

```swift
@EnvironmentObject var queryClient: QueryClient

// Invalidate specific query
queryClient.invalidateQuery(key: "posts")

// Invalidate queries matching pattern
queryClient.invalidateQueries(matching: "user")

// Invalidate all queries
queryClient.invalidateAllQueries()
```

### Invalidation Strategies

```swift
// Immediate invalidation and refetch
queryClient.invalidateQuery(key: "posts", refetch: true)

// Mark as stale without refetching
queryClient.invalidateQuery(key: "posts", refetch: false)

// Conditional invalidation
if shouldInvalidate {
    queryClient.invalidateQuery(key: "posts")
}
```

## Background Refetching

### Automatic Refetching

Data automatically refetches when:
- Component mounts and data is stale
- Window regains focus
- Network reconnects
- Query is invalidated

### Refetch Configuration

```swift
@Query(
    "posts",
    refetchOnMount: true,
    refetchOnWindowFocus: true,
    refetchOnReconnect: true
) var posts: QueryResult<[Post]>
```

### Refetch Intervals

```swift
// Refetch every 30 seconds
@Query("posts", refetchInterval: .seconds(30)) var posts: QueryResult<[Post]>

// Conditional refetch interval
@Query("posts", refetchInterval: isActive ? .seconds(10) : nil) var posts: QueryResult<[Post]>
```

## Structural Sharing

### Automatic Optimization

SwiftUI Query automatically shares unchanged data to prevent unnecessary re-renders:

```swift
struct PostList: View {
    @Query("posts") var posts: QueryResult<[Post]>
    
    var body: some View {
        List(posts.data ?? []) { post in
            PostRow(post: post)
        }
    }
}

struct PostRow: View {
    let post: Post
    
    var body: some View {
        // Only re-renders if this specific post changes
        VStack(alignment: .leading) {
            Text(post.title)
            Text(post.body)
        }
    }
}
```

### Manual Optimization

```swift
// Custom equality check for better structural sharing
struct Post: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    
    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id && 
        lhs.title == rhs.title && 
        lhs.body == rhs.body
    }
}
```

## Query Deduplication

### Automatic Deduplication

Multiple components requesting the same data share a single network request:

```swift
// Both components use the same query
struct PostList: View {
    @Query("posts") var posts: QueryResult<[Post]>
    // UI implementation
}

struct PostCount: View {
    @Query("posts") var posts: QueryResult<[Post]>
    var body: some View {
        Text("Posts: \(posts.data?.count ?? 0)")
    }
}
```

### Request Deduplication

```swift
// Multiple rapid calls to the same query are deduplicated
@Query("posts") var posts: QueryResult<[Post]>

// All these calls will share the same network request
Button("Refresh 1") { posts.refetch() }
Button("Refresh 2") { posts.refetch() }
Button("Refresh 3") { posts.refetch() }
```

## Cache Persistence

### Memory Cache

Default cache is in-memory and cleared when app terminates:

```swift
// Standard memory cache
@Query("posts") var posts: QueryResult<[Post]>
```

### Persistent Cache

Implement persistent caching with custom storage:

```swift
class PersistentQueryClient: QueryClient {
    override func setQueryData<T>(key: String, data: T) {
        super.setQueryData(key: key, data: data)
        
        // Save to persistent storage
        saveToPersistentStorage(key: key, data: data)
    }
    
    override func getQueryData<T>(key: String) -> T? {
        // Try memory cache first
        if let data = super.getQueryData(key: key) as? T {
            return data
        }
        
        // Fall back to persistent storage
        return loadFromPersistentStorage(key: key)
    }
}
```

## Cache Optimization

### Memory Management

```swift
// Configure cache size limits
let queryClient = QueryClient(
    defaultOptions: QueryClientOptions(
        maxCacheSize: 100,
        gcTime: .minutes(5)
    )
)

// Manual garbage collection
queryClient.gc()
```

### Selective Caching

```swift
// Don't cache sensitive data
@Query("user-secrets", cacheTime: .zero) var secrets: QueryResult<UserSecrets>

// Cache static data forever
@Query("app-config", cacheTime: .infinity) var config: QueryResult<AppConfig>
```

### Cache Warming

```swift
// Prefetch commonly used data
func warmCache() {
    queryClient.prefetchQuery(key: "posts") {
        try await fetchPosts()
    }
    
    queryClient.prefetchQuery(key: "user-profile") {
        try await fetchUserProfile()
    }
}
```

## Performance Monitoring

### Cache Metrics

```swift
// Monitor cache performance
queryClient.onCacheMetrics { metrics in
    print("Cache hits: \(metrics.hits)")
    print("Cache misses: \(metrics.misses)")
    print("Cache size: \(metrics.size)")
    print("Hit rate: \(metrics.hitRate)")
}
```

### Query Performance

```swift
// Monitor individual query performance
queryClient.onQueryPerformance { metrics in
    print("Query: \(metrics.key)")
    print("Duration: \(metrics.duration)")
    print("Cache hit: \(metrics.cacheHit)")
    print("Network time: \(metrics.networkTime)")
}
```

## Best Practices

1. **Use appropriate stale times** based on data freshness requirements
2. **Configure cache times** to balance memory usage and performance
3. **Implement proper cache keys** that uniquely identify data
4. **Use structural sharing** to optimize rendering performance
5. **Monitor cache metrics** to identify optimization opportunities
6. **Consider persistent caching** for critical data
7. **Implement cache warming** for better user experience
8. **Use selective caching** for sensitive or large data sets

## Common Patterns

### Hierarchical Caching

```swift
// User data
@Query(["user", userID]) var user: QueryResult<User>

// User's posts
@Query(["user", userID, "posts"]) var userPosts: QueryResult<[Post]>

// User's settings
@Query(["user", userID, "settings"]) var userSettings: QueryResult<UserSettings>
```

### Conditional Caching

```swift
// Cache based on user role
@Query(
    "sensitive-data",
    cacheTime: isAdmin ? .minutes(5) : .zero
) var sensitiveData: QueryResult<SensitiveData>
```

### Cache Synchronization

```swift
// Synchronize related caches
func updateUserProfile(_ profile: UserProfile) {
    queryClient.setQueryData(key: ["user", profile.id], data: profile)
    queryClient.invalidateQueries(matching: ["user", profile.id])
}
```

## See Also

- <doc:Queries>
- <doc:QueryClient>
- <doc:QueryInvalidation>