# Offline Support

Handle offline scenarios and network connectivity gracefully.

## Overview

SwiftUI Query provides robust offline support, allowing your app to work seamlessly when network connectivity is limited or unavailable. It automatically handles network state changes and provides strategies for offline data management.

## Automatic Offline Handling

### Network State Detection

SwiftUI Query automatically detects network connectivity:

```swift
@EnvironmentObject var queryClient: QueryClient

var body: some View {
    VStack {
        if queryClient.isOnline {
            Text("Online")
                .foregroundColor(.green)
        } else {
            Text("Offline")
                .foregroundColor(.red)
        }
    }
}
```

### Offline Query Behavior

```swift
@Query("posts") var posts: QueryResult<[Post]>

// When offline:
// - Queries return cached data if available
// - New queries remain in loading state
// - Retries are paused until online

var body: some View {
    Group {
        if !queryClient.isOnline && posts.data == nil {
            OfflineView()
        } else {
            PostsList(posts: posts.data ?? [])
        }
    }
}
```

## Network Modes

### Online Mode

```swift
@Query("posts", networkMode: .online) var posts: QueryResult<[Post]>

// Only executes when online
// Pauses when offline
```

### Offline First Mode

```swift
@Query("posts", networkMode: .offlineFirst) var posts: QueryResult<[Post]>

// Always returns cached data first
// Fetches in background when online
```

### Always Mode

```swift
@Query("posts", networkMode: .always) var posts: QueryResult<[Post]>

// Always attempts to fetch, even offline
// Useful for testing offline behavior
```

## Offline Data Strategies

### Cache-First Strategy

```swift
@Query(
    "posts",
    networkMode: .offlineFirst,
    staleTime: .hours(24)
) var posts: QueryResult<[Post]>

// Returns cached data immediately
// Refetches when online and stale
```

### Optimistic Offline Updates

```swift
struct OfflinePostCreator: View {
    @Mutation var createPost: MutationResult<Post>
    @EnvironmentObject var queryClient: QueryClient
    
    func createPostOffline(_ post: Post) {
        // Store optimistically in cache
        queryClient.setQueryData(key: "posts") { oldPosts in
            [post] + oldPosts
        }
        
        // Queue for sync when online
        OfflineQueue.shared.add(operation: .createPost(post))
        
        // Attempt mutation (will retry when online)
        createPost.mutate {
            try await createNewPost(post)
        }
    }
}
```

## Offline Queue Management

### Operation Queue

```swift
class OfflineQueue: ObservableObject {
    static let shared = OfflineQueue()
    
    @Published var pendingOperations: [OfflineOperation] = []
    
    func add(operation: OfflineOperation) {
        pendingOperations.append(operation)
        saveToStorage()
    }
    
    func sync() async {
        for operation in pendingOperations {
            do {
                try await operation.execute()
                remove(operation)
            } catch {
                // Handle sync errors
                operation.incrementRetryCount()
            }
        }
    }
    
    private func saveToStorage() {
        // Persist operations to local storage
        UserDefaults.standard.set(
            try? JSONEncoder().encode(pendingOperations),
            forKey: "pendingOperations"
        )
    }
}

enum OfflineOperation: Codable {
    case createPost(Post)
    case updatePost(Post)
    case deletePost(String)
    
    func execute() async throws {
        switch self {
        case .createPost(let post):
            try await createNewPost(post)
        case .updatePost(let post):
            try await updateExistingPost(post)
        case .deletePost(let id):
            try await deleteExistingPost(id: id)
        }
    }
}
```

### Automatic Sync

```swift
class NetworkManager: ObservableObject {
    @Published var isOnline = true
    
    init() {
        startNetworkMonitoring()
    }
    
    private func startNetworkMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { _ in
            self.isOnline = true
            Task {
                await OfflineQueue.shared.sync()
            }
        }
    }
}
```

## Offline UI Patterns

### Offline Indicator

```swift
struct OfflineIndicator: View {
    @EnvironmentObject var queryClient: QueryClient
    @StateObject private var offlineQueue = OfflineQueue.shared
    
    var body: some View {
        VStack {
            if !queryClient.isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline")
                    
                    if !offlineQueue.pendingOperations.isEmpty {
                        Text("(\(offlineQueue.pendingOperations.count) pending)")
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
}
```

### Offline-First Data Display

```swift
struct OfflinePostsList: View {
    @Query("posts", networkMode: .offlineFirst) var posts: QueryResult<[Post]>
    @EnvironmentObject var queryClient: QueryClient
    
    var body: some View {
        VStack {
            if !queryClient.isOnline {
                Text("Showing cached data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            List(posts.data ?? []) { post in
                PostRow(post: post)
            }
            .refreshable {
                if queryClient.isOnline {
                    posts.refetch()
                }
            }
        }
    }
}
```

## Conflict Resolution

### Last Writer Wins

```swift
func resolveConflict<T: Identifiable>(
    local: T,
    remote: T,
    lastModified: (T) -> Date
) -> T {
    return lastModified(local) > lastModified(remote) ? local : remote
}
```

### Merge Strategy

```swift
func mergePosts(local: [Post], remote: [Post]) -> [Post] {
    var merged: [String: Post] = [:]
    
    // Add all remote posts
    for post in remote {
        merged[post.id] = post
    }
    
    // Override with local posts that are newer
    for post in local {
        if let remotePost = merged[post.id],
           post.lastModified > remotePost.lastModified {
            merged[post.id] = post
        } else if merged[post.id] == nil {
            merged[post.id] = post
        }
    }
    
    return Array(merged.values)
}
```

## Persistent Storage

### Cache Persistence

```swift
class PersistentCache {
    private let userDefaults = UserDefaults.standard
    
    func save<T: Codable>(_ data: T, forKey key: String) {
        do {
            let encoded = try JSONEncoder().encode(data)
            userDefaults.set(encoded, forKey: key)
        } catch {
            print("Failed to save data: \(error)")
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load data: \(error)")
            return nil
        }
    }
}
```

### Offline-First Query Client

```swift
class OfflineQueryClient: QueryClient {
    private let persistentCache = PersistentCache()
    
    override func getQueryData<T>(key: String) -> T? {
        // Try memory cache first
        if let data = super.getQueryData(key: key) as? T {
            return data
        }
        
        // Fall back to persistent cache
        return persistentCache.load(T.self, forKey: key)
    }
    
    override func setQueryData<T>(key: String, data: T) {
        // Update memory cache
        super.setQueryData(key: key, data: data)
        
        // Persist to storage
        persistentCache.save(data, forKey: key)
    }
}
```

## Background Sync

### Scheduled Sync

```swift
class BackgroundSyncManager {
    func scheduleSync() {
        let identifier = "com.app.background-sync"
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    func handleBackgroundSync() {
        Task {
            await OfflineQueue.shared.sync()
        }
    }
}
```

### Opportunistic Sync

```swift
func opportunisticSync() {
    guard queryClient.isOnline else { return }
    
    // Sync pending operations
    Task {
        await OfflineQueue.shared.sync()
    }
    
    // Refresh stale data
    queryClient.refetchQueries(stale: true)
}
```

## Testing Offline Scenarios

### Mock Network State

```swift
class MockNetworkManager: ObservableObject {
    @Published var isOnline = true
    
    func simulateOffline() {
        isOnline = false
    }
    
    func simulateOnline() {
        isOnline = true
    }
}
```

### Offline Testing

```swift
func testOfflineQuery() {
    let mockNetwork = MockNetworkManager()
    let queryClient = QueryClient(networkManager: mockNetwork)
    
    // Simulate offline
    mockNetwork.simulateOffline()
    
    // Test query behavior
    let query = Query("posts", queryClient: queryClient)
    
    // Should return cached data or remain loading
    XCTAssertTrue(query.isLoading || query.data != nil)
}
```

## Error Handling

### Offline Error States

```swift
enum OfflineError: Error {
    case networkUnavailable
    case syncFailed(underlying: Error)
    case conflictDetected
    case storageError
}

@Query("posts") var posts: QueryResult<[Post]>

if case .error(let error) = posts.state {
    switch error {
    case OfflineError.networkUnavailable:
        Text("Network unavailable. Showing cached data.")
    case OfflineError.syncFailed(let underlying):
        Text("Sync failed: \(underlying.localizedDescription)")
    default:
        Text("An error occurred: \(error.localizedDescription)")
    }
}
```

### Retry Strategies

```swift
@Query(
    "posts",
    retryCount: 3,
    retryDelay: .exponential(base: 2)
) var posts: QueryResult<[Post]>

// Automatically retries with exponential backoff
// Pauses retries when offline
```

## Best Practices

1. **Implement proper offline indicators** to inform users
2. **Use cache-first strategies** for better offline experience
3. **Queue operations** for later sync when offline
4. **Implement conflict resolution** for concurrent modifications
5. **Persist critical data** to local storage
6. **Test offline scenarios** thoroughly
7. **Provide graceful degradation** when features require connectivity
8. **Implement background sync** for seamless user experience

## Common Patterns

### Progressive Enhancement

```swift
struct ProgressivePostView: View {
    @Query("posts", networkMode: .offlineFirst) var posts: QueryResult<[Post]>
    @EnvironmentObject var queryClient: QueryClient
    
    var body: some View {
        VStack {
            // Core functionality works offline
            List(posts.data ?? []) { post in
                PostRow(post: post)
            }
            
            // Enhanced features require online
            if queryClient.isOnline {
                Button("Share") {
                    sharePost()
                }
                Button("Sync Comments") {
                    syncComments()
                }
            }
        }
    }
}
```

### Offline-First Forms

```swift
struct OfflinePostForm: View {
    @State private var title = ""
    @State private var body = ""
    @Mutation var createPost: MutationResult<Post>
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Body", text: $body)
            
            Button("Save") {
                let post = Post(title: title, body: body)
                
                // Save locally first
                saveToLocalStorage(post)
                
                // Sync when online
                createPost.mutate {
                    try await createNewPost(post)
                }
            }
        }
    }
}
```

## See Also

- <doc:Queries>
- <doc:Mutations>
- <doc:Caching>
- <doc:QueryClient>