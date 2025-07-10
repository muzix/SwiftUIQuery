# Infinite Queries

Handle paginated data with infinite scrolling capabilities.

## Overview

Infinite queries are perfect for implementing paginated data fetching, infinite scrolling, and load-more functionality. They automatically manage pagination state and provide seamless data loading experiences.

## Basic Infinite Query

```swift
struct InfinitePostsList: View {
    @InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts.allData) { post in
                    PostRow(post: post)
                }
                
                if posts.hasNextPage {
                    Button("Load More") {
                        posts.fetchNextPage()
                    }
                    .disabled(posts.isFetchingNextPage)
                }
            }
        }
    }
    
    private func fetchPosts(page: Int) async throws -> PostsPage {
        let url = URL(string: "https://api.example.com/posts?page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(PostsPage.self, from: data)
    }
}

struct PostsPage: Codable {
    let posts: [Post]
    let nextPage: Int?
    let hasMore: Bool
}
```

## Infinite Query Configuration

### Basic Configuration

```swift
@InfiniteQuery(
    "posts",
    getNextPageParam: { lastPage in
        lastPage.nextPage
    }
) var posts: InfiniteQueryResult<PostsPage>
```

### Advanced Configuration

```swift
@InfiniteQuery(
    "posts",
    getNextPageParam: { lastPage in
        lastPage.hasMore ? lastPage.nextPage : nil
    },
    getPreviousPageParam: { firstPage in
        firstPage.previousPage
    },
    maxPages: 10,
    staleTime: .minutes(5)
) var posts: InfiniteQueryResult<PostsPage>
```

## Page Parameters

### Next Page Parameter

```swift
@InfiniteQuery(
    "posts",
    getNextPageParam: { lastPage in
        // Return next page parameter or nil if no more pages
        lastPage.hasMore ? lastPage.nextCursor : nil
    }
) var posts: InfiniteQueryResult<PostsPage>
```

### Previous Page Parameter

```swift
@InfiniteQuery(
    "posts",
    getPreviousPageParam: { firstPage in
        // Return previous page parameter or nil if no previous pages
        firstPage.hasPrevious ? firstPage.previousCursor : nil
    }
) var posts: InfiniteQueryResult<PostsPage>
```

## Accessing Data

### All Data

```swift
@InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>

// Get all data across all pages
let allPosts = posts.allData

// Render all data
ForEach(allPosts) { post in
    PostRow(post: post)
}
```

### Individual Pages

```swift
@InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>

// Get individual pages
let pages = posts.pages

// Render by page
ForEach(pages.indices, id: \.self) { pageIndex in
    let page = pages[pageIndex]
    Section("Page \(pageIndex + 1)") {
        ForEach(page.posts) { post in
            PostRow(post: post)
        }
    }
}
```

## Infinite Scrolling

### Automatic Loading

```swift
struct InfiniteScrollView: View {
    @InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts.allData) { post in
                    PostRow(post: post)
                        .onAppear {
                            // Load more when near the end
                            if post == posts.allData.last && posts.hasNextPage {
                                posts.fetchNextPage()
                            }
                        }
                }
                
                if posts.isFetchingNextPage {
                    ProgressView()
                        .padding()
                }
            }
        }
    }
}
```

### Manual Loading

```swift
struct ManualLoadingView: View {
    @InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        VStack {
            List(posts.allData) { post in
                PostRow(post: post)
            }
            
            if posts.hasNextPage {
                Button("Load More") {
                    posts.fetchNextPage()
                }
                .disabled(posts.isFetchingNextPage)
            }
        }
    }
}
```

## Bidirectional Scrolling

### Previous and Next Pages

```swift
struct BidirectionalScrollView: View {
    @InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        VStack {
            if posts.hasPreviousPage {
                Button("Load Previous") {
                    posts.fetchPreviousPage()
                }
                .disabled(posts.isFetchingPreviousPage)
            }
            
            List(posts.allData) { post in
                PostRow(post: post)
            }
            
            if posts.hasNextPage {
                Button("Load Next") {
                    posts.fetchNextPage()
                }
                .disabled(posts.isFetchingNextPage)
            }
        }
    }
}
```

## Cursor-Based Pagination

### Cursor Implementation

```swift
struct CursorPaginatedView: View {
    @InfiniteQuery(
        "posts",
        getNextPageParam: { lastPage in
            lastPage.nextCursor
        }
    ) var posts: InfiniteQueryResult<CursorPage>
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts.allData) { post in
                    PostRow(post: post)
                }
            }
        }
    }
    
    private func fetchPosts(cursor: String?) async throws -> CursorPage {
        var url = URL(string: "https://api.example.com/posts")!
        
        if let cursor = cursor {
            url = url.appending(queryItems: [
                URLQueryItem(name: "cursor", value: cursor)
            ])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(CursorPage.self, from: data)
    }
}

struct CursorPage: Codable {
    let posts: [Post]
    let nextCursor: String?
}
```

## Offset-Based Pagination

### Offset Implementation

```swift
struct OffsetPaginatedView: View {
    @InfiniteQuery(
        "posts",
        getNextPageParam: { lastPage in
            lastPage.hasMore ? lastPage.nextOffset : nil
        }
    ) var posts: InfiniteQueryResult<OffsetPage>
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts.allData) { post in
                    PostRow(post: post)
                }
            }
        }
    }
    
    private func fetchPosts(offset: Int) async throws -> OffsetPage {
        let url = URL(string: "https://api.example.com/posts?offset=\(offset)&limit=20")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(OffsetPage.self, from: data)
    }
}

struct OffsetPage: Codable {
    let posts: [Post]
    let nextOffset: Int
    let hasMore: Bool
}
```

## Error Handling

### Page-Level Errors

```swift
@InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>

if let error = posts.error {
    VStack {
        Text("Error loading posts: \(error.localizedDescription)")
        Button("Retry") {
            posts.refetch()
        }
    }
}

// Handle next page errors
if let nextPageError = posts.nextPageError {
    VStack {
        Text("Error loading more posts: \(nextPageError.localizedDescription)")
        Button("Retry") {
            posts.fetchNextPage()
        }
    }
}
```

## Advanced Features

### Maximum Pages

```swift
@InfiniteQuery(
    "posts",
    maxPages: 5,
    getNextPageParam: { lastPage in
        lastPage.nextPage
    }
) var posts: InfiniteQueryResult<PostsPage>

// Automatically stops fetching after 5 pages
```

### Reverse Pagination

```swift
@InfiniteQuery(
    "messages",
    reverse: true,
    getNextPageParam: { lastPage in
        lastPage.olderMessagesCursor
    }
) var messages: InfiniteQueryResult<MessagesPage>

// Newest messages first, load older messages
```

### Refetching

```swift
@InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>

// Refetch all pages
Button("Refresh All") {
    posts.refetch()
}

// Refetch first page only
Button("Refresh First Page") {
    posts.refetchFirstPage()
}
```

## State Management

### Query States

```swift
@InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>

// Overall query state
switch posts.state {
case .loading:
    ProgressView()
case .success:
    PostsList(posts: posts.allData)
case .error(let error):
    ErrorView(error: error)
}

// Individual page states
if posts.isFetchingNextPage {
    Text("Loading more...")
}

if posts.isFetchingPreviousPage {
    Text("Loading previous...")
}
```

### Page Information

```swift
@InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>

// Page count
let pageCount = posts.pages.count

// Has more pages
let hasMore = posts.hasNextPage

// Total items across all pages
let totalItems = posts.allData.count
```

## Performance Optimization

### Virtualization

```swift
struct VirtualizedInfiniteList: View {
    @InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts.allData) { post in
                    PostRow(post: post)
                        .onAppear {
                            loadMoreIfNeeded(for: post)
                        }
                }
            }
        }
    }
    
    private func loadMoreIfNeeded(for post: Post) {
        let thresholdIndex = posts.allData.count - 5
        if let index = posts.allData.firstIndex(of: post),
           index >= thresholdIndex,
           posts.hasNextPage {
            posts.fetchNextPage()
        }
    }
}
```

### Memory Management

```swift
@InfiniteQuery(
    "posts",
    maxPages: 10,
    getNextPageParam: { lastPage in
        lastPage.nextPage
    }
) var posts: InfiniteQueryResult<PostsPage>

// Automatically manages memory by limiting pages
```

## Best Practices

1. **Use appropriate pagination strategy** (cursor vs offset)
2. **Implement proper loading states** for better UX
3. **Handle errors gracefully** with retry mechanisms
4. **Use virtualization** for large datasets
5. **Set reasonable page limits** to manage memory
6. **Implement threshold-based loading** for smooth scrolling
7. **Consider bidirectional scrolling** for chat-like interfaces
8. **Cache appropriately** based on data freshness needs

## Common Patterns

### Search with Infinite Scrolling

```swift
struct SearchableInfiniteList: View {
    @State private var searchText = ""
    @InfiniteQuery("posts", searchText) var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    ForEach(posts.allData) { post in
                        PostRow(post: post)
                    }
                }
            }
            .searchable(text: $searchText)
        }
    }
}
```

### Pull-to-Refresh

```swift
struct RefreshableInfiniteList: View {
    @InfiniteQuery("posts") var posts: InfiniteQueryResult<PostsPage>
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts.allData) { post in
                    PostRow(post: post)
                }
            }
        }
        .refreshable {
            await posts.refetch()
        }
    }
}
```

## See Also

- <doc:Queries>
- <doc:Caching>
- <doc:QueryClient>