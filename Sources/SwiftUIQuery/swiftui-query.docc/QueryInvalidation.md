# Query Invalidation

Learn how to invalidate queries to keep your data fresh and synchronized.

## Overview

Query invalidation is the process of marking cached data as stale and triggering refetches. This ensures your app displays the most up-to-date information after data changes.

## When to Invalidate

### After Mutations

The most common scenario is invalidating queries after successful mutations:

```swift
@Mutation var createPost: MutationResult<Post>
@EnvironmentObject var queryClient: QueryClient

createPost.mutate(
    onSuccess: { _ in
        // Invalidate posts list to show new post
        queryClient.invalidateQuery(key: "posts")
    }
) {
    try await createNewPost(post)
}
```

### Manual Refresh

Allow users to manually refresh data:

```swift
@Query("posts") var posts: QueryResult<[Post]>
@EnvironmentObject var queryClient: QueryClient

Button("Refresh") {
    queryClient.invalidateQuery(key: "posts")
}
```

## Invalidation Methods

### Single Query Invalidation

```swift
@EnvironmentObject var queryClient: QueryClient

// Invalidate specific query
queryClient.invalidateQuery(key: "posts")

// Invalidate query with parameters
queryClient.invalidateQuery(key: ["user", userID])

// Invalidate with options
queryClient.invalidateQuery(
    key: "posts",
    refetch: true,
    exact: true
)
```

### Pattern Matching

```swift
// Invalidate all user-related queries
queryClient.invalidateQueries(matching: "user")

// Invalidate all queries starting with "posts"
queryClient.invalidateQueries(matching: "posts")

// Invalidate all queries containing userID
queryClient.invalidateQueries(matching: userID)
```

### Bulk Invalidation

```swift
// Invalidate all queries
queryClient.invalidateAllQueries()

// Invalidate multiple specific queries
queryClient.invalidateQueries(keys: ["posts", "users", "comments"])
```

## Invalidation Options

### Refetch Control

```swift
// Invalidate and refetch immediately
queryClient.invalidateQuery(key: "posts", refetch: true)

// Mark as stale without refetching
queryClient.invalidateQuery(key: "posts", refetch: false)

// Only refetch if query is currently active
queryClient.invalidateQuery(key: "posts", refetch: .ifActive)
```

### Exact Matching

```swift
// Exact key match only
queryClient.invalidateQuery(key: "posts", exact: true)

// Partial key matching (default)
queryClient.invalidateQuery(key: "posts", exact: false)
```

## Selective Invalidation

### Conditional Invalidation

```swift
func invalidateUserData(userID: String) {
    // Only invalidate if user is active
    if isUserActive(userID) {
        queryClient.invalidateQueries(matching: ["user", userID])
    }
}
```

### Filter-Based Invalidation

```swift
// Invalidate queries based on custom criteria
queryClient.invalidateQueries { query in
    // Only invalidate stale queries
    return query.isStale
}

// Invalidate queries by state
queryClient.invalidateQueries { query in
    // Only invalidate error queries
    return query.state == .error
}
```

## Advanced Invalidation Patterns

### Cascade Invalidation

```swift
func invalidatePostData(postID: String) {
    // Invalidate the specific post
    queryClient.invalidateQuery(key: ["post", postID])
    
    // Invalidate related queries
    queryClient.invalidateQuery(key: "posts")
    queryClient.invalidateQuery(key: ["post", postID, "comments"])
    queryClient.invalidateQuery(key: "user-posts")
}
```

### Hierarchical Invalidation

```swift
func invalidateUserHierarchy(userID: String) {
    // Invalidate user data
    queryClient.invalidateQuery(key: ["user", userID])
    
    // Invalidate user's posts
    queryClient.invalidateQuery(key: ["user", userID, "posts"])
    
    // Invalidate user's settings
    queryClient.invalidateQuery(key: ["user", userID, "settings"])
    
    // Invalidate user's notifications
    queryClient.invalidateQuery(key: ["user", userID, "notifications"])
}
```

### Batch Invalidation

```swift
func invalidateRelatedQueries(postID: String) {
    queryClient.batchInvalidate {
        invalidateQuery(key: ["post", postID])
        invalidateQuery(key: "posts")
        invalidateQuery(key: ["post", postID, "comments"])
        invalidateQuery(key: "recent-posts")
    }
}
```

## Invalidation with Mutations

### Automatic Invalidation

```swift
@Mutation(
    invalidateQueries: ["posts", "user-posts"]
) var createPost: MutationResult<Post>

// Automatically invalidates specified queries on success
```

### Custom Invalidation Logic

```swift
@Mutation var updatePost: MutationResult<Post>
@EnvironmentObject var queryClient: QueryClient

updatePost.mutate(
    onSuccess: { updatedPost in
        // Invalidate specific post
        queryClient.invalidateQuery(key: ["post", updatedPost.id])
        
        // Invalidate post lists
        queryClient.invalidateQueries(matching: "posts")
        
        // Invalidate user's posts if author changed
        if updatedPost.authorID != originalPost.authorID {
            queryClient.invalidateQuery(key: ["user", updatedPost.authorID, "posts"])
        }
    }
) {
    try await updateExistingPost(post)
}
```

## Performance Considerations

### Debounced Invalidation

```swift
class DebouncedInvalidator {
    private let queryClient: QueryClient
    private var invalidationTimer: Timer?
    
    init(queryClient: QueryClient) {
        self.queryClient = queryClient
    }
    
    func invalidateAfterDelay(key: String, delay: TimeInterval = 0.5) {
        invalidationTimer?.invalidate()
        invalidationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            queryClient.invalidateQuery(key: key)
        }
    }
}
```

### Smart Invalidation

```swift
func smartInvalidateUserData(userID: String) {
    // Check if user data is already fresh
    if let userData = queryClient.getQueryData(key: ["user", userID]) as? User,
       !queryClient.isQueryStale(key: ["user", userID]) {
        // Data is fresh, skip invalidation
        return
    }
    
    // Invalidate only if necessary
    queryClient.invalidateQuery(key: ["user", userID])
}
```

## Testing Invalidation

### Mock Invalidation

```swift
class MockQueryClient: QueryClient {
    var invalidatedQueries: [String] = []
    
    override func invalidateQuery(key: String) {
        invalidatedQueries.append(key)
        super.invalidateQuery(key: key)
    }
    
    func verifyInvalidation(key: String) -> Bool {
        return invalidatedQueries.contains(key)
    }
}
```

### Invalidation Testing

```swift
func testPostCreationInvalidation() {
    let mockClient = MockQueryClient()
    let viewModel = PostListViewModel(queryClient: mockClient)
    
    // Create post
    viewModel.createPost(title: "Test", body: "Test body")
    
    // Verify invalidation
    XCTAssert(mockClient.verifyInvalidation(key: "posts"))
    XCTAssert(mockClient.verifyInvalidation(key: "user-posts"))
}
```

## Common Patterns

### CRUD Operations

```swift
// Create
createPost.mutate(
    onSuccess: { _ in
        queryClient.invalidateQuery(key: "posts")
    }
) { try await createNewPost(post) }

// Update
updatePost.mutate(
    onSuccess: { updatedPost in
        queryClient.invalidateQuery(key: ["post", updatedPost.id])
        queryClient.invalidateQuery(key: "posts")
    }
) { try await updateExistingPost(post) }

// Delete
deletePost.mutate(
    onSuccess: { _ in
        queryClient.invalidateQuery(key: "posts")
        queryClient.removeQuery(key: ["post", postID])
    }
) { try await deleteExistingPost(id: postID) }
```

### Real-time Updates

```swift
func handleWebSocketMessage(_ message: WebSocketMessage) {
    switch message.type {
    case .postCreated:
        queryClient.invalidateQuery(key: "posts")
    case .postUpdated:
        queryClient.invalidateQuery(key: ["post", message.postID])
        queryClient.invalidateQuery(key: "posts")
    case .postDeleted:
        queryClient.removeQuery(key: ["post", message.postID])
        queryClient.invalidateQuery(key: "posts")
    }
}
```

### Background Refresh

```swift
func backgroundRefresh() {
    // Invalidate critical queries when app becomes active
    queryClient.invalidateQueries(matching: "user")
    queryClient.invalidateQueries(matching: "notifications")
    queryClient.invalidateQueries(matching: "messages")
}
```

## Best Practices

1. **Invalidate related queries** after mutations
2. **Use pattern matching** for efficient bulk invalidation
3. **Consider performance impact** of frequent invalidations
4. **Implement debouncing** for rapid invalidations
5. **Use exact matching** when appropriate
6. **Test invalidation logic** thoroughly
7. **Document invalidation strategies** for your team
8. **Monitor invalidation performance** in production

## Invalidation Strategies

### Conservative Strategy

```swift
// Invalidate broadly to ensure data consistency
func conservativeInvalidation() {
    queryClient.invalidateAllQueries()
}
```

### Targeted Strategy

```swift
// Invalidate only affected queries
func targetedInvalidation(postID: String) {
    queryClient.invalidateQuery(key: ["post", postID])
    queryClient.invalidateQuery(key: "posts")
}
```

### Hybrid Strategy

```swift
// Balance between performance and consistency
func hybridInvalidation(postID: String) {
    // Immediate: invalidate specific post
    queryClient.invalidateQuery(key: ["post", postID])
    
    // Delayed: invalidate related queries
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        queryClient.invalidateQuery(key: "posts")
        queryClient.invalidateQuery(key: "user-posts")
    }
}
```

## See Also

- <doc:Queries>
- <doc:Mutations>
- <doc:Caching>
- <doc:QueryClient>