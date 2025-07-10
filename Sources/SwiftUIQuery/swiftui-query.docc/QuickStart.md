# Quick Start

Get up and running with SwiftUI Query in minutes.

## Overview

This guide will help you set up SwiftUI Query in your app and make your first query.

## Step 1: Setup Query Client

First, create a query client and provide it to your app:

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

## Step 2: Make Your First Query

Use the `@Query` property wrapper to fetch data:

```swift
import SwiftUI
import SwiftUIQuery

struct Post: Codable, Identifiable {
    let id: Int
    let title: String
    let body: String
}

struct ContentView: View {
    @Query("posts") var posts: QueryResult<[Post]>
    
    var body: some View {
        NavigationView {
            Group {
                switch posts.state {
                case .loading:
                    ProgressView()
                case .success(let data):
                    List(data) { post in
                        VStack(alignment: .leading) {
                            Text(post.title)
                                .font(.headline)
                            Text(post.body)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                case .error(let error):
                    Text("Error: \(error.localizedDescription)")
                }
            }
            .navigationTitle("Posts")
        }
    }
    
    private func fetchPosts() async throws -> [Post] {
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Post].self, from: data)
    }
}
```

## Step 3: Add Mutations

For data modifications, use the `@Mutation` property wrapper:

```swift
struct CreatePostView: View {
    @Mutation var createPost: MutationResult<Post>
    @State private var title = ""
    @State private var body = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Title", text: $title)
                TextField("Body", text: $body, axis: .vertical)
                    .lineLimit(3...)
                
                Button("Create Post") {
                    createPost.mutate(createNewPost)
                }
                .disabled(createPost.isLoading)
            }
            .navigationTitle("New Post")
        }
    }
    
    private func createNewPost() async throws -> Post {
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
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

## Key Concepts

- **Query Keys**: Unique identifiers for your queries (e.g., `"posts"`, `["post", id]`)
- **Query Functions**: Async functions that return your data
- **Automatic Caching**: Data is cached automatically and reused across components
- **Background Refetching**: Data is refetched when the app becomes active or network reconnects

## Next Steps

- <doc:BasicUsage>
- <doc:Queries>
- <doc:Mutations>