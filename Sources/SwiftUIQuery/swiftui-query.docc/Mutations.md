# Mutations

Learn how to handle data modifications with mutations.

## Overview

Mutations are used for creating, updating, or deleting data. Unlike queries, mutations are not automatically cached and are typically triggered by user actions.

## Basic Mutation Usage

### Simple Mutation

```swift
struct CreatePostView: View {
    @Mutation var createPost: MutationResult<Post>
    @State private var title = ""
    @State private var body = ""
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Body", text: $body)
            
            Button("Create Post") {
                createPost.mutate {
                    try await createNewPost(title: title, body: body)
                }
            }
            .disabled(createPost.isLoading)
        }
    }
    
    private func createNewPost(title: String, body: String) async throws -> Post {
        let url = URL(string: "https://api.example.com/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let postData = ["title": title, "body": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: postData)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Post.self, from: data)
    }
}
```

### Mutation with Parameters

```swift
struct UpdatePostView: View {
    let postID: String
    @Mutation var updatePost: MutationResult<Post>
    @State private var title = ""
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            
            Button("Update Post") {
                updatePost.mutate {
                    try await updateExistingPost(id: postID, title: title)
                }
            }
            .disabled(updatePost.isLoading)
        }
    }
    
    private func updateExistingPost(id: String, title: String) async throws -> Post {
        let url = URL(string: "https://api.example.com/posts/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let postData = ["title": title]
        request.httpBody = try JSONSerialization.data(withJSONObject: postData)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Post.self, from: data)
    }
}
```

## Mutation States

Mutations have similar states to queries:

```swift
@Mutation var createPost: MutationResult<Post>

switch createPost.state {
case .idle:
    // Mutation hasn't been called yet
    Button("Create Post") {
        createPost.mutate(createNewPost)
    }
    
case .loading:
    ProgressView()
    
case .success(let post):
    Text("Post created successfully: \(post.title)")
    
case .error(let error):
    Text("Error: \(error.localizedDescription)")
}
```

## Mutation Options

### Retry Configuration

```swift
@Mutation(
    retryCount: 3,
    retryDelay: .seconds(1)
) var createPost: MutationResult<Post>
```

### Timeout Configuration

```swift
@Mutation(timeout: .seconds(30)) var uploadFile: MutationResult<FileUpload>
```

## Optimistic Updates

### Simple Optimistic Update

```swift
struct PostListView: View {
    @Query("posts") var posts: QueryResult<[Post]>
    @Mutation var createPost: MutationResult<Post>
    @EnvironmentObject var queryClient: QueryClient
    
    func addPost(_ post: Post) {
        // Optimistically update the cache
        queryClient.setQueryData(key: "posts") { oldPosts in
            oldPosts + [post]
        }
        
        // Perform the mutation
        createPost.mutate {
            try await createNewPost(post)
        }
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
    
    createPost.mutate(
        onSuccess: { _ in
            // Mutation succeeded, keep optimistic update
        },
        onError: { _ in
            // Rollback on error
            queryClient.setQueryData(key: "posts", data: previousData)
        }
    ) {
        try await createNewPost(post)
    }
}
```

## Query Invalidation

### Invalidate Related Queries

```swift
@Mutation var createPost: MutationResult<Post>
@EnvironmentObject var queryClient: QueryClient

createPost.mutate(
    onSuccess: { _ in
        // Invalidate posts list to refetch fresh data
        queryClient.invalidateQuery(key: "posts")
    }
) {
    try await createNewPost(post)
}
```

### Multiple Invalidations

```swift
createPost.mutate(
    onSuccess: { _ in
        queryClient.invalidateQuery(key: "posts")
        queryClient.invalidateQuery(key: "user-posts")
        queryClient.invalidateQuery(key: "post-count")
    }
) {
    try await createNewPost(post)
}
```

## Mutation Callbacks

### Success Callback

```swift
@Mutation var createPost: MutationResult<Post>

createPost.mutate(
    onSuccess: { post in
        print("Created post: \(post.title)")
        // Navigate to new post
    }
) {
    try await createNewPost(post)
}
```

### Error Callback

```swift
createPost.mutate(
    onError: { error in
        print("Failed to create post: \(error)")
        // Show error message
    }
) {
    try await createNewPost(post)
}
```

### Combined Callbacks

```swift
createPost.mutate(
    onSuccess: { post in
        queryClient.invalidateQuery(key: "posts")
        navigationController.popViewController(animated: true)
    },
    onError: { error in
        showAlert(title: "Error", message: error.localizedDescription)
    }
) {
    try await createNewPost(post)
}
```

## Advanced Mutation Patterns

### Batch Mutations

```swift
@Mutation var batchUpdate: MutationResult<[Post]>

func updateMultiplePosts(_ posts: [Post]) {
    batchUpdate.mutate {
        try await withThrowingTaskGroup(of: Post.self) { group in
            for post in posts {
                group.addTask {
                    try await updatePost(post)
                }
            }
            
            var results: [Post] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}
```

### Conditional Mutations

```swift
@Mutation var updatePost: MutationResult<Post>
@State private var hasChanges = false

Button("Save Changes") {
    if hasChanges {
        updatePost.mutate {
            try await updateExistingPost(id: postID, changes: changes)
        }
    }
}
.disabled(!hasChanges || updatePost.isLoading)
```

### Mutation Chaining

```swift
@Mutation var uploadImage: MutationResult<ImageUpload>
@Mutation var createPost: MutationResult<Post>

func createPostWithImage(image: UIImage, title: String) {
    uploadImage.mutate(
        onSuccess: { imageUpload in
            createPost.mutate {
                try await createNewPost(
                    title: title,
                    imageURL: imageUpload.url
                )
            }
        }
    ) {
        try await uploadImageToServer(image)
    }
}
```

## Error Handling

### Mutation-Specific Errors

```swift
enum MutationError: Error {
    case validationError(String)
    case networkError(Error)
    case serverError(Int)
}

@Mutation var createPost: MutationResult<Post>

if case .error(let error) = createPost.state {
    switch error {
    case MutationError.validationError(let message):
        Text("Validation error: \(message)")
    case MutationError.networkError:
        Text("Network error. Please try again.")
    case MutationError.serverError(let code):
        Text("Server error: \(code)")
    default:
        Text("An unexpected error occurred.")
    }
}
```

### Retry Failed Mutations

```swift
@Mutation var createPost: MutationResult<Post>

if case .error = createPost.state {
    Button("Retry") {
        createPost.retry()
    }
}
```

## Best Practices

1. **Use mutations for data modifications** (create, update, delete)
2. **Handle all mutation states** (idle, loading, success, error)
3. **Implement optimistic updates** for better user experience
4. **Invalidate related queries** after successful mutations
5. **Use appropriate error handling** with user-friendly messages
6. **Consider rollback strategies** for failed optimistic updates
7. **Batch related mutations** when possible for better performance
8. **Use mutation callbacks** for navigation and UI updates

## Common Patterns

### Create, Read, Update, Delete (CRUD)

```swift
// Create
@Mutation var createPost: MutationResult<Post>

// Update
@Mutation var updatePost: MutationResult<Post>

// Delete
@Mutation var deletePost: MutationResult<Void>

// Read (Query)
@Query("posts") var posts: QueryResult<[Post]>
```

### Form Submission

```swift
struct PostForm: View {
    @Mutation var submitPost: MutationResult<Post>
    @State private var title = ""
    @State private var body = ""
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Body", text: $body)
            
            Button("Submit") {
                submitPost.mutate {
                    try await submitFormData(title: title, body: body)
                }
            }
            .disabled(submitPost.isLoading)
        }
    }
}
```

## See Also

- <doc:Queries>
- <doc:OptimisticUpdates>
- <doc:QueryInvalidation>