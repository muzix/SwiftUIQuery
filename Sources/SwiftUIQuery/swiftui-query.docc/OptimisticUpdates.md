# Optimistic Updates

Implement optimistic UI updates for better user experience.

## Overview

Optimistic updates allow you to update the UI immediately when a user performs an action, before the server response arrives. This creates a snappy, responsive user experience while handling potential failures gracefully.

## Basic Optimistic Update

```swift
struct PostList: View {
    @Query("posts") var posts: QueryResult<[Post]>
    @Mutation var createPost: MutationResult<Post>
    @EnvironmentObject var queryClient: QueryClient
    
    func addPost(_ post: Post) {
        // Optimistically update the cache
        queryClient.setQueryData(key: "posts") { oldPosts in
            oldPosts + [post]
        }
        
        // Perform the actual mutation
        createPost.mutate(
            onSuccess: { _ in
                // Mutation succeeded, keep optimistic update
                queryClient.invalidateQuery(key: "posts")
            },
            onError: { error in
                // Rollback optimistic update on error
                queryClient.setQueryData(key: "posts") { oldPosts in
                    oldPosts.filter { $0.id != post.id }
                }
                showError(error)
            }
        ) {
            try await createNewPost(post)
        }
    }
}
```

## Optimistic Update Patterns

### Create Operations

```swift
struct CreatePostView: View {
    @Query("posts") var posts: QueryResult<[Post]>
    @Mutation var createPost: MutationResult<Post>
    @EnvironmentObject var queryClient: QueryClient
    @State private var title = ""
    @State private var body = ""
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Body", text: $body)
            
            Button("Create Post") {
                optimisticallyCreatePost()
            }
        }
    }
    
    private func optimisticallyCreatePost() {
        let tempPost = Post(
            id: UUID().uuidString,
            title: title,
            body: body,
            isOptimistic: true
        )
        
        // Optimistic update
        queryClient.setQueryData(key: "posts") { oldPosts in
            [tempPost] + oldPosts
        }
        
        createPost.mutate(
            onSuccess: { realPost in
                // Replace optimistic post with real post
                queryClient.setQueryData(key: "posts") { oldPosts in
                    oldPosts.map { post in
                        post.id == tempPost.id ? realPost : post
                    }
                }
            },
            onError: { error in
                // Remove optimistic post on error
                queryClient.setQueryData(key: "posts") { oldPosts in
                    oldPosts.filter { $0.id != tempPost.id }
                }
                showError(error)
            }
        ) {
            try await createNewPost(title: title, body: body)
        }
    }
}
```

### Update Operations

```swift
struct EditPostView: View {
    let post: Post
    @Query("posts") var posts: QueryResult<[Post]>
    @Mutation var updatePost: MutationResult<Post>
    @EnvironmentObject var queryClient: QueryClient
    @State private var title: String
    
    init(post: Post) {
        self.post = post
        self._title = State(initialValue: post.title)
    }
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            
            Button("Update Post") {
                optimisticallyUpdatePost()
            }
        }
    }
    
    private func optimisticallyUpdatePost() {
        let originalPost = post
        let updatedPost = Post(
            id: post.id,
            title: title,
            body: post.body,
            isOptimistic: true
        )
        
        // Optimistic update
        queryClient.setQueryData(key: "posts") { oldPosts in
            oldPosts.map { post in
                post.id == originalPost.id ? updatedPost : post
            }
        }
        
        updatePost.mutate(
            onSuccess: { realPost in
                // Replace optimistic post with real post
                queryClient.setQueryData(key: "posts") { oldPosts in
                    oldPosts.map { post in
                        post.id == originalPost.id ? realPost : post
                    }
                }
            },
            onError: { error in
                // Rollback to original post on error
                queryClient.setQueryData(key: "posts") { oldPosts in
                    oldPosts.map { post in
                        post.id == originalPost.id ? originalPost : post
                    }
                }
                showError(error)
            }
        ) {
            try await updateExistingPost(id: post.id, title: title)
        }
    }
}
```

### Delete Operations

```swift
struct PostRow: View {
    let post: Post
    @Query("posts") var posts: QueryResult<[Post]>
    @Mutation var deletePost: MutationResult<Void>
    @EnvironmentObject var queryClient: QueryClient
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(post.title)
                    .opacity(post.isOptimistic ? 0.5 : 1.0)
                Text(post.body)
                    .opacity(post.isOptimistic ? 0.5 : 1.0)
            }
            
            Spacer()
            
            Button("Delete") {
                optimisticallyDeletePost()
            }
            .foregroundColor(.red)
        }
    }
    
    private func optimisticallyDeletePost() {
        let originalPosts = queryClient.getQueryData(key: "posts") as? [Post] ?? []
        
        // Optimistic update - remove post
        queryClient.setQueryData(key: "posts") { oldPosts in
            oldPosts.filter { $0.id != post.id }
        }
        
        deletePost.mutate(
            onSuccess: { _ in
                // Deletion succeeded, keep optimistic update
                queryClient.invalidateQuery(key: "posts")
            },
            onError: { error in
                // Rollback optimistic update on error
                queryClient.setQueryData(key: "posts", data: originalPosts)
                showError(error)
            }
        ) {
            try await deleteExistingPost(id: post.id)
        }
    }
}
```

## Advanced Optimistic Updates

### Multiple Cache Updates

```swift
func optimisticallyLikePost(_ post: Post) {
    let updatedPost = Post(
        id: post.id,
        title: post.title,
        body: post.body,
        likes: post.likes + 1,
        isLiked: true
    )
    
    // Update multiple related caches
    queryClient.setQueryData(key: "posts") { oldPosts in
        oldPosts.map { $0.id == post.id ? updatedPost : $0 }
    }
    
    queryClient.setQueryData(key: ["post", post.id]) { _ in
        updatedPost
    }
    
    queryClient.setQueryData(key: "liked-posts") { oldLikedPosts in
        oldLikedPosts + [updatedPost]
    }
    
    likePost.mutate(
        onSuccess: { realPost in
            // Update all caches with real data
            queryClient.setQueryData(key: "posts") { oldPosts in
                oldPosts.map { $0.id == post.id ? realPost : $0 }
            }
            queryClient.setQueryData(key: ["post", post.id], data: realPost)
        },
        onError: { error in
            // Rollback all optimistic updates
            queryClient.setQueryData(key: "posts") { oldPosts in
                oldPosts.map { $0.id == post.id ? post : $0 }
            }
            queryClient.setQueryData(key: ["post", post.id], data: post)
            queryClient.setQueryData(key: "liked-posts") { oldLikedPosts in
                oldLikedPosts.filter { $0.id != post.id }
            }
        }
    ) {
        try await likePostOnServer(id: post.id)
    }
}
```

### Optimistic Update Context

```swift
struct OptimisticUpdateContext {
    let rollback: () -> Void
    let commit: () -> Void
}

extension QueryClient {
    func optimisticallyUpdate<T>(
        key: String,
        updater: @escaping ([T]) -> [T]
    ) -> OptimisticUpdateContext {
        let originalData = getQueryData(key: key) as? [T] ?? []
        
        // Apply optimistic update
        setQueryData(key: key, updater: updater)
        
        return OptimisticUpdateContext(
            rollback: {
                setQueryData(key: key, data: originalData)
            },
            commit: {
                invalidateQuery(key: key)
            }
        )
    }
}
```

## UI Feedback for Optimistic Updates

### Visual Indicators

```swift
struct OptimisticPostRow: View {
    let post: Post
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(post.title)
                    .opacity(post.isOptimistic ? 0.6 : 1.0)
                Text(post.body)
                    .opacity(post.isOptimistic ? 0.6 : 1.0)
            }
            
            Spacer()
            
            if post.isOptimistic {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .background(
            post.isOptimistic ? 
            Color.yellow.opacity(0.1) : 
            Color.clear
        )
    }
}
```

### Animation Support

```swift
struct AnimatedOptimisticList: View {
    @Query("posts") var posts: QueryResult<[Post]>
    
    var body: some View {
        List(posts.data ?? []) { post in
            OptimisticPostRow(post: post)
                .transition(.opacity.combined(with: .scale))
        }
        .animation(.easeInOut(duration: 0.3), value: posts.data)
    }
}
```

## Error Handling

### Graceful Rollback

```swift
struct GracefulOptimisticUpdate {
    let queryClient: QueryClient
    
    func performOptimisticUpdate<T>(
        key: String,
        optimisticUpdate: @escaping ([T]) -> [T],
        mutation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        let originalData = queryClient.getQueryData(key: key) as? [T] ?? []
        
        // Apply optimistic update
        queryClient.setQueryData(key: key, updater: optimisticUpdate)
        
        Task {
            do {
                let result = try await mutation()
                onSuccess(result)
                queryClient.invalidateQuery(key: key)
            } catch {
                // Rollback on error
                queryClient.setQueryData(key: key, data: originalData)
                onError(error)
            }
        }
    }
}
```

### Retry with Optimistic Updates

```swift
func optimisticallyUpdateWithRetry<T>(
    key: String,
    optimisticUpdate: @escaping ([T]) -> [T],
    mutation: @escaping () async throws -> T,
    maxRetries: Int = 3
) {
    let originalData = queryClient.getQueryData(key: key) as? [T] ?? []
    
    // Apply optimistic update
    queryClient.setQueryData(key: key, updater: optimisticUpdate)
    
    func attemptMutation(attempt: Int = 0) {
        Task {
            do {
                let result = try await mutation()
                queryClient.invalidateQuery(key: key)
            } catch {
                if attempt < maxRetries {
                    // Retry after delay
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    attemptMutation(attempt: attempt + 1)
                } else {
                    // Rollback after max retries
                    queryClient.setQueryData(key: key, data: originalData)
                }
            }
        }
    }
    
    attemptMutation()
}
```

## Best Practices

1. **Use temporary IDs** for optimistic creates to avoid conflicts
2. **Provide visual feedback** to indicate optimistic state
3. **Implement proper rollback** for failed operations
4. **Consider network conditions** when deciding on optimistic updates
5. **Test error scenarios** thoroughly
6. **Use animations** to smooth transitions
7. **Update related caches** consistently
8. **Implement retry mechanisms** for transient failures

## Common Patterns

### Optimistic Toggle

```swift
struct OptimisticToggle: View {
    @State private var isEnabled: Bool
    @Mutation var toggleSetting: MutationResult<Bool>
    @EnvironmentObject var queryClient: QueryClient
    
    init(initialValue: Bool) {
        self._isEnabled = State(initialValue: initialValue)
    }
    
    var body: some View {
        Toggle("Setting", isOn: $isEnabled)
            .onChange(of: isEnabled) { newValue in
                optimisticallyToggle(newValue)
            }
    }
    
    private func optimisticallyToggle(_ newValue: Bool) {
        let previousValue = !newValue
        
        toggleSetting.mutate(
            onError: { error in
                // Rollback toggle on error
                isEnabled = previousValue
            }
        ) {
            try await updateSettingOnServer(newValue)
        }
    }
}
```

### Optimistic Counter

```swift
struct OptimisticCounter: View {
    @State private var count: Int
    @Mutation var updateCount: MutationResult<Int>
    
    init(initialCount: Int) {
        self._count = State(initialValue: initialCount)
    }
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.largeTitle)
            
            HStack {
                Button("-") {
                    optimisticallyDecrement()
                }
                Button("+") {
                    optimisticallyIncrement()
                }
            }
        }
    }
    
    private func optimisticallyIncrement() {
        let previousCount = count
        count += 1
        
        updateCount.mutate(
            onError: { error in
                count = previousCount
            }
        ) {
            try await updateCountOnServer(count)
        }
    }
    
    private func optimisticallyDecrement() {
        let previousCount = count
        count -= 1
        
        updateCount.mutate(
            onError: { error in
                count = previousCount
            }
        ) {
            try await updateCountOnServer(count)
        }
    }
}
```

## See Also

- <doc:Mutations>
- <doc:QueryClient>
- <doc:Caching>