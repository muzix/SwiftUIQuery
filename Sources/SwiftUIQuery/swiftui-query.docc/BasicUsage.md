# Basic Usage

Learn the fundamental patterns for using SwiftUI Query.

## Overview

SwiftUI Query provides property wrappers that integrate seamlessly with SwiftUI's declarative syntax, making data fetching as simple as declaring a state variable.

## Query States

Every query has one of three states:

- **Loading**: Initial data fetch in progress
- **Success**: Data fetched successfully
- **Error**: An error occurred during fetching

```swift
@Query("user", id: userID) var user: QueryResult<User>

switch user.state {
case .loading:
    ProgressView()
case .success(let userData):
    UserProfileView(user: userData)
case .error(let error):
    ErrorView(error: error)
}
```

## Query Keys

Query keys uniquely identify your queries and determine when they should be refetched:

```swift
// Simple string key
@Query("posts") var posts: QueryResult<[Post]>

// Array key with parameters
@Query(["user", userID]) var user: QueryResult<User>

// Complex key with multiple parameters
@Query(["posts", "user", userID, "page", pageNumber]) var userPosts: QueryResult<[Post]>
```

## Query Functions

Query functions perform the actual data fetching:

```swift
struct PostListView: View {
    @Query("posts") var posts: QueryResult<[Post]>
    
    var body: some View {
        // UI code...
    }
    
    private func fetchPosts() async throws -> [Post] {
        let url = URL(string: "https://api.example.com/posts")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Post].self, from: data)
    }
}
```

## Dependent Queries

Some queries depend on data from other queries:

```swift
struct UserProfileView: View {
    let userID: String
    
    @Query(["user", userID]) var user: QueryResult<User>
    @Query(["posts", userID]) var userPosts: QueryResult<[Post]>
    
    var body: some View {
        Group {
            if case .success(let userData) = user.state {
                VStack {
                    Text(userData.name)
                    
                    // Posts query only executes if user query succeeded
                    if case .success(let posts) = userPosts.state {
                        List(posts) { post in
                            PostRowView(post: post)
                        }
                    }
                }
            }
        }
    }
}
```

## Background Refetching

Queries automatically refetch in the background when:

- The app becomes active (window focus)
- Network reconnects
- Query is invalidated
- Stale time expires

```swift
@Query("posts", staleTime: .minutes(5)) var posts: QueryResult<[Post]>
```

## Manual Refetching

You can manually trigger a refetch:

```swift
@Query("posts") var posts: QueryResult<[Post]>

Button("Refresh") {
    posts.refetch()
}
```

## Error Handling

Handle errors gracefully with retry functionality:

```swift
@Query("posts", retryCount: 3) var posts: QueryResult<[Post]>

if case .error(let error) = posts.state {
    VStack {
        Text("Error: \(error.localizedDescription)")
        Button("Retry") {
            posts.refetch()
        }
    }
}
```

## Loading States

Show loading indicators during data fetching:

```swift
@Query("posts") var posts: QueryResult<[Post]>

ZStack {
    if posts.isLoading {
        ProgressView()
    }
    
    if case .success(let data) = posts.state {
        List(data) { post in
            PostRowView(post: post)
        }
    }
}
```

## Best Practices

1. **Use descriptive query keys** that clearly identify the data
2. **Handle all query states** (loading, success, error)
3. **Keep query functions pure** and focused on data fetching
4. **Use appropriate stale times** based on your data freshness requirements
5. **Implement proper error handling** with user-friendly messages

## Next Steps

- <doc:Queries>
- <doc:Mutations>
- <doc:Caching>