# Quick Start

Get up and running with SwiftUI Query in minutes.

## Overview

SwiftUI Query brings TanStack Query's powerful data fetching patterns to SwiftUI. This guide shows you how to make your first query and understand the core concepts.

## Basic Query Example

Use the `@Query` property wrapper to fetch data declaratively:

```swift
import SwiftUI
import SwiftUIQuery

struct Post: Sendable, Codable, Identifiable {
    let id: Int
    let title: String
    let body: String
}

struct PostsView: View {
    @Query("posts", fetch: fetchPosts)
    var postsQuery
    
    var body: some View {
        NavigationStack {
            VStack {
                if postsQuery.isLoading {
                    ProgressView("Loading posts...")
                } else if let posts = postsQuery.data {
                    List(posts) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title)
                                .font(.headline)
                            Text(post.body)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let error = postsQuery.error {
                    VStack {
                        Text("Failed to load posts")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                        Button("Retry") {
                            _postsQuery.refetch()
                        }
                    }
                }
            }
            .navigationTitle("Posts")
        }
        .attach(_postsQuery) // Enable lifecycle-driven refetching
    }
}

@Sendable
func fetchPosts() async throws -> [Post] {
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Post].self, from: data)
}
```

## Query Execution Patterns

SwiftUI Query supports two execution patterns based on your `refetchOnAppear` setting:

### Pattern 1: Automatic Execution (Static Data)

For data that should fetch once and not refetch on view appearances:

```swift
@Query(
    "app-config", 
    fetch: fetchConfig,
    options: QueryOptions(refetchOnAppear: .never, staleTime: .hours(24))
)
var configQuery

// Usage: No .attach() needed - fetches automatically when view loads
```

### Pattern 2: Lifecycle-Driven Execution (Dynamic Data)

For data that should refetch when views appear (default behavior):

```swift
@Query(
    "user-posts", 
    fetch: fetchPosts,
    options: QueryOptions(refetchOnAppear: .ifStale, staleTime: .minutes(5))
)
var postsQuery

// Usage: Requires .attach() to enable lifecycle events
.attach(_postsQuery)
```

## Query State Properties

The query state provides comprehensive information about your request:

```swift
@Query("data", fetch: fetchData) var dataQuery

// Status properties
dataQuery.status        // .idle, .loading, .success, .error
dataQuery.isLoading     // true during initial load
dataQuery.isFetching    // true during any fetch (including background)
dataQuery.isSuccess     // true when data loaded successfully
dataQuery.isError       // true when an error occurred
dataQuery.hasData       // true when data is available
dataQuery.isStale       // true when data needs refreshing

// Data and error
dataQuery.data          // The fetched data (optional)
dataQuery.error         // Any error that occurred (optional)
```

## Query Actions

Control your queries programmatically:

```swift
// Manual refetch
_dataQuery.refetch()

// Mark data as stale (triggers refetch on next appear if .ifStale)
_dataQuery.invalidate()

// Reset to initial state
_dataQuery.reset()
```

## Configuration Options

Customize query behavior with `QueryOptions`:

```swift
@Query(
    "posts", 
    fetch: fetchPosts,
    options: QueryOptions(
        staleTime: .minutes(5),           // How long data stays fresh
        refetchOnAppear: .ifStale,        // When to refetch on view appear
        refetchOnReconnect: .ifStale,     // When to refetch on network reconnect
        enabled: true,                    // Whether query should execute
        retry: 3                          // Number of retry attempts
    )
)
var postsQuery
```

## Common Patterns

### Static Configuration Data
```swift
@Query("theme", fetch: fetchTheme, options: QueryOptions(refetchOnAppear: .never))
var themeQuery
// Fetches once when view loads, no .attach() needed
```

### Dynamic User Data
```swift
@Query("profile", fetch: fetchProfile, options: QueryOptions(refetchOnAppear: .ifStale))
var profileQuery
// Refetches if stale when view appears, requires .attach()
```

### Real-time Data
```swift
@Query("notifications", fetch: fetchNotifications, options: QueryOptions(
    refetchOnAppear: .always,
    staleTime: .zero
))
var notificationsQuery
// Always refetches on view appear, requires .attach()
```

## Navigation Example

Queries work seamlessly with SwiftUI navigation:

```swift
struct PostListView: View {
    @Query("posts", fetch: fetchPosts) var postsQuery
    
    var body: some View {
        NavigationStack {
            List(postsQuery.data ?? []) { post in
                NavigationLink(destination: PostDetailView(postId: post.id)) {
                    Text(post.title)
                }
            }
        }
        .attach(_postsQuery)
    }
}

struct PostDetailView: View {
    let postId: Int
    @Query var postQuery: QueryState<Post>
    
    init(postId: Int) {
        self.postId = postId
        self._postQuery = Query(
            "post-\(postId)",
            fetch: { try await fetchPost(id: postId) }
        )
    }
    
    var body: some View {
        VStack {
            if let post = postQuery.data {
                Text(post.title).font(.title)
                Text(post.body)
            } else if postQuery.isLoading {
                ProgressView()
            }
        }
        .attach(_postQuery)
    }
}
```

## Key Benefits

- **Automatic Caching**: Queries with the same key share cached data
- **Background Refetching**: Data refreshes when app regains focus or network reconnects
- **Optimistic UI**: Loading and error states are handled automatically
- **Swift 6 Ready**: Full concurrency support with `@Sendable` functions
- **SwiftUI Native**: Built specifically for SwiftUI using `@Observable` and `DynamicProperty`

## Next Steps

- <doc:Queries> - Deep dive into query configuration and patterns
- <doc:QueryInvalidation> - Learn about cache invalidation strategies
- <doc:Caching> - Understand caching behavior and stale time