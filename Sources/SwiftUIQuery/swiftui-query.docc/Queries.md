# Queries

Deep dive into query configuration and advanced usage patterns.

## Overview

Queries are the heart of SwiftUI Query. They handle data fetching, caching, and synchronization with a declarative API that integrates seamlessly with SwiftUI.

## Query Configuration

### Basic Configuration

```swift
@Query("posts") var posts: QueryResult<[Post]>
```

### Advanced Configuration

```swift
@Query(
    "posts",
    staleTime: .minutes(5),
    cacheTime: .minutes(30),
    retryCount: 3,
    retryDelay: .seconds(1)
) var posts: QueryResult<[Post]>
```

## Query Options

### Stale Time

Controls how long data is considered fresh:

```swift
@Query("posts", staleTime: .minutes(5)) var posts: QueryResult<[Post]>
```

### Cache Time

Controls how long unused data stays in cache:

```swift
@Query("posts", cacheTime: .hours(1)) var posts: QueryResult<[Post]>
```

### Retry Configuration

Configure automatic retry behavior:

```swift
@Query(
    "posts",
    retryCount: 3,
    retryDelay: .seconds(2)
) var posts: QueryResult<[Post]>
```

### Enabled/Disabled Queries

Conditionally enable queries:

```swift
@Query("user", enabled: userID != nil) var user: QueryResult<User?>
```

## Query Keys

### Simple Keys

```swift
@Query("posts") var posts: QueryResult<[Post]>
```

### Parameterized Keys

```swift
@Query(["posts", "user", userID]) var userPosts: QueryResult<[Post]>
```

### Complex Keys

```swift
@Query([
    "posts", 
    "filter", filter,
    "sort", sortOrder,
    "page", pageNumber
]) var filteredPosts: QueryResult<PagedResult<Post>>
```

## Query Functions

### Simple Fetch

```swift
private func fetchPosts() async throws -> [Post] {
    let url = URL(string: "https://api.example.com/posts")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Post].self, from: data)
}
```

### Parameterized Fetch

```swift
private func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}
```

### Error Handling in Query Functions

```swift
private func fetchPosts() async throws -> [Post] {
    let url = URL(string: "https://api.example.com/posts")!
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode([Post].self, from: data)
    } catch {
        throw APIError.networkError(error)
    }
}
```

## Background Refetching

### Automatic Refetching

Queries automatically refetch when:
- App becomes active
- Network reconnects
- Query is invalidated
- Stale time expires

### Manual Refetching

```swift
@Query("posts") var posts: QueryResult<[Post]>

Button("Refresh") {
    posts.refetch()
}
```

### Refetch Intervals

```swift
@Query("posts", refetchInterval: .seconds(30)) var posts: QueryResult<[Post]>
```

## Dependent Queries

### Sequential Dependencies

```swift
struct UserDashboard: View {
    @Query("user") var user: QueryResult<User>
    @Query("preferences") var preferences: QueryResult<UserPreferences>
    
    var body: some View {
        Group {
            if case .success(let userData) = user.state {
                // Only fetch preferences after user is loaded
                PreferencesView(userID: userData.id)
            }
        }
    }
}
```

### Parallel Dependencies

```swift
struct Dashboard: View {
    @Query("user") var user: QueryResult<User>
    @Query("posts") var posts: QueryResult<[Post]>
    @Query("notifications") var notifications: QueryResult<[Notification]>
    
    var body: some View {
        VStack {
            // All queries execute in parallel
            UserHeader(user: user)
            PostsList(posts: posts)
            NotificationsList(notifications: notifications)
        }
    }
}
```

## Query Invalidation

### Invalidate Specific Query

```swift
@EnvironmentObject var queryClient: QueryClient

queryClient.invalidateQuery(key: "posts")
```

### Invalidate Query Pattern

```swift
// Invalidate all user-related queries
queryClient.invalidateQueries(matching: "user")
```

### Invalidate All Queries

```swift
queryClient.invalidateAllQueries()
```

## Optimistic Updates

### Simple Optimistic Update

```swift
@Query("posts") var posts: QueryResult<[Post]>
@EnvironmentObject var queryClient: QueryClient

func addPost(_ post: Post) {
    // Optimistically update the cache
    queryClient.setQueryData(key: "posts") { oldPosts in
        oldPosts + [post]
    }
    
    // Perform actual mutation
    Task {
        try await createPost(post)
    }
}
```

### Rollback on Error

```swift
func addPost(_ post: Post) {
    let previousData = queryClient.getQueryData(key: "posts")
    
    // Optimistic update
    queryClient.setQueryData(key: "posts") { oldPosts in
        oldPosts + [post]
    }
    
    Task {
        do {
            try await createPost(post)
        } catch {
            // Rollback on error
            queryClient.setQueryData(key: "posts", data: previousData)
        }
    }
}
```

## Performance Optimization

### Query Deduplication

Multiple components requesting the same data will share a single network request:

```swift
// Both components will share the same query
struct PostList: View {
    @Query("posts") var posts: QueryResult<[Post]>
    // ...
}

struct PostCount: View {
    @Query("posts") var posts: QueryResult<[Post]>
    // ...
}
```

### Structural Sharing

SwiftUI Query automatically shares unchanged data to prevent unnecessary re-renders:

```swift
// Only components using changed data will re-render
@Query("posts") var posts: QueryResult<[Post]>
```

## Error Handling

### Retry Logic

```swift
@Query(
    "posts",
    retryCount: 3,
    retryDelay: .seconds(2)
) var posts: QueryResult<[Post]>
```

### Custom Error Handling

```swift
@Query("posts") var posts: QueryResult<[Post]>

if case .error(let error) = posts.state {
    switch error {
    case APIError.networkError:
        Text("Network error. Please check your connection.")
    case APIError.unauthorized:
        Text("Please log in to continue.")
    default:
        Text("An unexpected error occurred.")
    }
}
```

## Best Practices

1. **Use meaningful query keys** that describe the data being fetched
2. **Configure appropriate stale times** based on data freshness requirements
3. **Handle all query states** (loading, success, error) in your UI
4. **Use dependent queries** to avoid fetching unnecessary data
5. **Implement proper error handling** with user-friendly messages
6. **Consider caching strategies** for different types of data
7. **Use query invalidation** to keep data fresh after mutations

## See Also

- <doc:Mutations>
- <doc:QueryClient>
- <doc:Caching>