# SwiftUI Query Pokemon Demo

This demo showcases real-world usage of SwiftUI Query with the Pokemon API. It demonstrates all the key features and patterns you need to build reactive, data-driven SwiftUI apps.

## 🚀 Features Demonstrated

### UseQuery Patterns
- **Basic Queries**: Fetch and display Pokemon lists
- **Detail Queries**: Load individual Pokemon with detailed information
- **Search Queries**: Dynamic queries based on user input with `enabled` parameter
- **Nested Queries**: Pokemon list rows load sprites independently
- **Different Cache Strategies**: List (5min), Details (10min), Sprites (15min)

### Real-World UI Patterns
- **Loading States**: Proper loading indicators and skeletons
- **Error Handling**: User-friendly error messages with retry functionality
- **Pull-to-Refresh**: Native SwiftUI refresh support with `result.refetch()`
- **Navigation**: Master-detail pattern with NavigationLink
- **Search Interface**: Real-time search with conditional query execution

### Advanced Features
- **Environment Injection**: QueryClient provided at app level
- **Type Safety**: Strongly typed Pokemon models
- **Preview Support**: SwiftUI previews for different states
- **Accessibility**: Proper accessibility labels and identifiers

## 📱 How to Run

1. **Open the Project**: Open `Example/swiftui-query-demo.xcodeproj` in Xcode
2. **Build and Run**: Press Cmd+R to build and run the demo
3. **Watch the Console**: The demo has cache logging enabled - see SwiftUI Query in action!
4. **Explore**: Browse Pokemon, tap for details, use search

## 📊 Cache Logging in Action

This demo has **cache logging enabled** by default! Watch the Xcode console to see how SwiftUI Query optimizes your app's data layer in real-time.

### What You'll See

#### Cache Operations
```
🚀 SwiftUI Query Demo Started - Cache logging enabled!
💡 Watch the console to see cache hits, misses, and state changes

📝 Query cache miss for key hash: "pokemon-list" - creating new query
🔄 QueryObserver switching to query hash: "pokemon-list"
💾 Setting data for query hash: "pokemon-list"
🔄 Query state updated (data changed) for hash: "pokemon-list"
```

#### Cache Efficiency
```
🎯 Query cache hit for key hash: "pokemon-list"
👁️ QueryObserver reusing existing query hash: "pokemon-list"
📊 QueryObserver reading query state for hash: "pokemon-list"
```

#### Query State Changes
```
🔄 Query state updated (status changed) for hash: "pokemon-1"
🗑️ Invalidating query cache for key hash: "pokemon-list"
🔄 Resetting query cache for hash: "pokemon-search-pikachu"
```

### Try These Interactions
- **Navigate between screens** → See cache hits when returning
- **Pull to refresh** → Watch invalidation and refetch
- **Search Pokemon** → New cache entries for each search term
- **Scroll the list** → Efficient sprite loading with individual caching
- **Leave and return to app** → Background refetch on focus

### Disable Logging
For production-like behavior, modify `swiftui_query_demoApp.swift`:
```swift
init() {
    // Disable cache logging
    // QueryLogger.shared.enableAll()
    
    // Or enable only specific components
    // QueryLogger.shared.enableQueryClientOnly()
}
```

## 🔍 Key Code Examples

### Basic UseQuery
```swift
UseQuery(
    queryKey: "pokemon-list",
    queryFn: { _ in try await PokemonAPI.fetchPokemonList(limit: 50) },
    staleTime: 5 * 60,  // 5 minutes
    gcTime: 10 * 60     // 10 minutes
) { result in
    if result.isLoading {
        ProgressView()
    } else if let pokemonList = result.data {
        List(pokemonList.results) { pokemon in
            // Pokemon list content
        }
        .refreshable {
            _ = await result.refetch()
        }
    }
}
```

### Conditional Queries
```swift
UseQuery(
    queryKey: "pokemon-search-\(searchText)",
    queryFn: { _ in try await PokemonAPI.searchPokemon(name: searchText) },
    enabled: !searchText.isEmpty,  // Only run when there's search text
    staleTime: 5 * 60
) { result in
    // Search results
}
```

### Nested Queries
```swift
// Pokemon list uses one query
UseQuery(queryKey: "pokemon-list", ...) { listResult in
    List(listResult.data?.results ?? []) { pokemon in
        // Each row uses another query for sprites
        UseQuery(queryKey: "sprite-\(pokemon.id)", ...) { spriteResult in
            AsyncImage(url: spriteResult.data?.spriteURL)
        }
    }
}
```

### Error Handling
```swift
if let error = result.error {
    ErrorView(error: error) {
        Task {
            _ = await result.refetch()  // Retry the query
        }
    }
}
```

## 🎯 What You'll Learn

### SwiftUI Query Concepts
- **Automatic Caching**: Identical queries are deduped and cached
- **Background Refetching**: Data stays fresh without user intervention
- **Stale-While-Revalidate**: Show cached data while fetching fresh data
- **Query Keys**: How to structure keys for optimal caching
- **Loading & Error States**: Handling different query states gracefully

### Architecture Benefits
- **Declarative**: Data requirements declared right in the view
- **Performant**: Intelligent caching reduces network requests
- **Resilient**: Automatic retry and error recovery
- **Type-Safe**: Full Swift type safety with Sendable protocols

## 📊 Performance Features

### Smart Caching
- **List Data**: 5 minute stale time (refreshes periodically)
- **Detail Data**: 10 minute stale time (less frequent changes)
- **Sprite Images**: 15 minute stale time (rarely change)

### Network Optimization
- **Deduplication**: Multiple components requesting same data share one request
- **Background Updates**: Data refreshes when stale without blocking UI
- **Garbage Collection**: Unused queries are cleaned up automatically

## 🧪 Testing Features

The demo includes SwiftUI previews for different states:

### Preview Examples
```swift
#Preview("Loading State") {
    UseQuery.previewLoading(queryKey: "pokemon-loading") { result in
        LoadingView()
    }
}

#Preview("Error State") {
    UseQuery.previewError(queryKey: "pokemon-error") { result in
        ErrorView(error: URLError(.notConnectedToInternet)) { }
    }
}
```

## 🚧 Try These Modifications

### Extend the Demo
1. **Add Favorites**: Use mutations to save/remove favorites
2. **Infinite Scrolling**: Implement pagination with UseInfiniteQuery (when available)
3. **Offline Support**: Add query persistence and offline indicators
4. **Advanced Search**: Multi-field search with query composition
5. **Real-time Updates**: Add query invalidation on app focus

### Experiment with Caching
```swift
// Very aggressive caching
staleTime: 60 * 60,  // 1 hour
gcTime: 24 * 60 * 60  // 24 hours

// Fresh data preference
staleTime: 0,         // Always stale
gcTime: 5 * 60        // 5 minutes
```

## 🌐 API Information

Uses the free Pokemon API (https://pokeapi.co/):
- **No API key required**
- **Rate limit friendly**
- **Rich relational data**
- **Perfect for demos**

### Endpoints Used
- `GET /pokemon` - List Pokemon
- `GET /pokemon/{id}` - Get Pokemon details
- `GET /pokemon/{name}` - Search Pokemon by name

## 📚 Next Steps

This demo covers the fundamentals of SwiftUI Query. Explore the source code to understand:
- How queries are structured and cached
- Error handling patterns
- Loading state management
- Navigation with query data
- Preview and testing strategies

The Pokemon API is perfect for experimenting with different query patterns since it's free, fast, and has rich data relationships!