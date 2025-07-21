# SwiftUI Query - API Design

This document defines the API design for SwiftUI Query, focusing on the useQuery clone implementation.

## useQuery API Clone - Design Exploration

### Current useQuery in React
```javascript
const { data, isLoading, error, refetch } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId),
  staleTime: 5 * 60 * 1000,
  gcTime: 10 * 60 * 1000,
  refetchOnWindowFocus: true,
  retry: 3,
  enabled: !!userId,
  select: (data) => data.profile,
  placeholderData: previousData => previousData,
  initialData: cachedUser,
  throwOnError: false,
  refetchInterval: 30000,
  refetchIntervalInBackground: false,
  refetchOnMount: true,
  refetchOnReconnect: true,
  notifyOnChangeProps: ['data', 'error'],
  meta: { source: 'userProfile' }
})
```

### SwiftUI API Design

#### Property Wrapper with Initializer

struct UserView {
    @Query(
        key: [FetchUserQuery(userId: "userId")],
        fetch: { try await apiClient.fetch(FetchUserQuery(userId: "userId")) },
        options: .init(
            select: { data in data.fragments.userFragment },
            placeholderData: { previousData in previousData },
            initialData: cachedUser,
            staleTime: .minutes(5),
            retry: 3,
            reportOnError: .always,
            refetchInterval: .seconds(30),
            refetchIntervalInBackground: .minutes(1),
            refetchOnReconnect: .ifStale,
            refetchOnAppear: .ifStale
        )
    ) var userQuery
}

#### Can be initialized in view init.

enum CustomQueryKey: QueryKey {
    case fetchUserQuery(userId: String)
}

struct UserView {
    let userId: String
    @Query<User> var userQuery

    init(userId: String) {
        _query = Query(
            key: [FetchUserQuery(userId: "userId")],
            fetch: { try await apiClient.fetch(FetchUserQuery(userId: "userId")) },
            select: { data in data.fragments.userFragment },
            placeholderData: { previousData in previousData },
            initialData: cachedUser,
            options: .init(
                staleTime: .minutes(5),
                retry: 3,
                reportOnError: .always,
                refetchInterval: .seconds(30),
                refetchIntervalInBackground: .minutes(1),
                refetchOnReconnect: .ifStale,
                refetchOnAppear: .ifStale
            )
        )
    }
}

#### QueryKey

Query key is simply anything which conform to QueryKey protocol

```swift
struct Query<Data> {

    private let key: QueryKey
}

protocol QueryKey: Hashable {}

enum CustomQueryKey: QueryKey {
    case fetchUser(userId: String)
}
```

#### How it works at high level

Query is a property wrapper leverage SwiftUI Dynamic Property. SwiftUI consider dynamic property as part of swiftui environment. Therefore we can use @State, @StateObject, @ObservedObject, @Environment or any SwiftUI stuff inside the property wrapper.

To help Query aware of view lifecycle, unlike react which leverage hook mechanism, in swiftui it will be manually works. We will provide a utility view modifier to help ease the boilerplate. Something like

```swift
struct AttachViewLifecycleModifier<Query: QueryProtocol>: ViewModifier {

    let query: Query

    init(query: Query) {
        self.query = query
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                query.onAppear()
            }
            .onDisappear {
                query.onDisappear()
            }
    }
}

extension View {
    func attach<Query: QueryProtocol>(query: Query) {
        modifier(AttachViewLifecycleModifier(query: query))
    }
}

// Usage
struct UserView: View {

    @Query<User> var userQuery

    var body: some View {
        Text("Hello")
            .attach(userQuery)
    } 
}
```


#### 3. Status Handling
```swift
// Enum-based status
switch userQuery.status {
case .loading: ProgressView()
case .success: UserView(userQuery.data!)
case .error: ErrorView(userQuery.error!)
case .idle: EmptyView()
}
```

#### 4. Type Safety with Generated Query Types
```swift
// Generated query types (from GraphQL codegen or similar)
struct GetUserQuery: QueryKey {
    let userId: String
}

struct GetDefaultLivestreamThumbnailUrlQuery: QueryKey {
    let currentUserId: String
}

// Usage with generated types as keys
@Query(
    fetch: { try await client.request(GetUserQuery(userId: userId)) }
) var userQuery

// With select transformation (like React example)
@Query(
    key: GetDefaultLivestreamThumbnailUrlQuery(currentUserId: currentUserId),
    fetch: { try await client.request(GetDefaultLivestreamThumbnailUrlQuery(currentUserId: currentUserId)) },
    select: { (data: GetDefaultLivestreamThumbnailUrlResponse) in 
        data.me?.defaultLivestreamThumbnailUrl 
    }
) var thumbnailQuery
```

### Query API

```swift
// Query state access
userQuery.status      // .idle, .loading, .success, .error
userQuery.data        // T?
userQuery.error       // Error?
userQuery.isLoading   // Bool
userQuery.isSuccess   // Bool
userQuery.isError     // Bool
userQuery.isFetching  // Bool (background refetch)
userQuery.isStale     // Bool

// Query actions
_userQuery.refetch()                    // Basic refetch
_userQuery.refetch { fetcher in         // ✨ NEW: Configure fetcher before refetch
    fetcher.searchTerm = "new value"    // Update dynamic properties
    fetcher.options = newOptions        // Modify fetcher configuration
}
_userQuery.invalidate()                 // Mark as stale
_userQuery.reset()                      // Reset to initial state
```

### FetchProtocol Architecture

SwiftUI Query now supports both closure-based and protocol-based fetching for maximum flexibility and dynamic input handling.

#### FetchProtocol Definition
```swift
@MainActor
public protocol FetchProtocol: AnyObject, Sendable {
    associatedtype Output: Sendable
    func fetch() async throws -> Output
}
```

#### Dynamic Input with FetchProtocol
Unlike closures, FetchProtocol objects can access dynamic properties at fetch time:

```swift
@MainActor
public final class PokemonSearchFetcher: ObservableObject, FetchProtocol {
    @Published public var searchTerm: String = ""
    @Published public var includeVariants: Bool = true
    
    public init(searchTerm: String = "") {
        self.searchTerm = searchTerm
    }
    
    public func fetch() async throws -> Pokemon {
        // Uses current searchTerm value (dynamic!)
        let cleanTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty else {
            throw SearchError.emptyTerm
        }
        
        let url = URL(string: "https://pokeapi.co/api/v2/pokemon/\(cleanTerm)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Pokemon.self, from: data)
    }
}
```

#### Usage Examples
```swift
struct SearchView: View {
    @State private var searchText = ""
    @StateObject private var fetcher = PokemonSearchFetcher()
    
    // Generic Query with FetchProtocol
    @Query<PokemonSearchFetcher> var searchQuery: QueryState<Pokemon>
    
    init() {
        self._searchQuery = Query(
            "pokemon-search",
            fetcher: fetcher,
            options: QueryOptions(staleTime: .seconds(30))
        )
    }
    
    var body: some View {
        VStack {
            TextField("Search Pokemon", text: $searchText)
                .onChange(of: searchText) { _, newValue in
                    fetcher.searchTerm = newValue
                }
            
            // NEW: Configure and refetch in one step
            Button("Search Pikachu") {
                _searchQuery.refetch { $0.searchTerm = "pikachu" }
            }
            
            Button("Search Charizard") {
                _searchQuery.refetch { $0.searchTerm = "charizard" }
            }
        }
        .attach(_searchQuery)
    }
}
```

#### Backward Compatibility
The closure-based API is still supported through automatic wrapping:

```swift
// Old way (still works)
@Query("user-\(userId)", fetch: {
    try await api.getUser(userId) // ⚠️ Captures static userId
}) var userQuery

// New way (dynamic)
@StateObject private var userFetcher = UserFetcher(userId: userId)
@Query("user-profile", fetcher: userFetcher) var userQuery
// ✅ userFetcher.userId can change dynamically
```

#### Generic Query Structure
```swift
@propertyWrapper @MainActor
public struct Query<F: FetchProtocol>: DynamicProperty, ViewLifecycleAttachable 
where F.Output: Sendable {
    
    public typealias T = F.Output
    public let fetcher: F  // Strongly typed fetcher
    
    // Initialization with FetchProtocol object
    public init(
        _ key: any QueryKey,
        fetcher: F,
        placeholderData: (@Sendable (T?) -> T?)? = nil,
        initialData: T? = nil,
        options: QueryOptions = .default
    )
    
    // Backward compatibility with closures
    public init<T: Sendable>(
        _ key: any QueryKey,
        fetch: @Sendable @escaping () async throws -> T,
        // ... other parameters
    ) where F.Output == T, F == Fetcher<T>
}
```

#### Benefits of FetchProtocol
1. **Dynamic Input**: Properties can change between fetches
2. **Type Safety**: Generic constraints ensure compile-time correctness
3. **Configurability**: Use `refetch { fetcher in ... }` to modify before fetching
4. **Testability**: Easy to mock FetchProtocol implementations
5. **Reusability**: Fetcher objects can be shared across queries
6. **Backward Compatibility**: Existing closure-based code continues to work

### Current Architecture Overview

SwiftUI Query follows TanStack Query's architecture with three main components:

#### 1. QueryClient - Central Management
```swift
@MainActor
public final class QueryClient: ObservableObject {
    private let queryCache: QueryCache
    public var defaultOptions: QueryOptions
    
    // Query lifecycle management
    public func invalidateQueries(filter: QueryFilter? = nil, refetchType: RefetchType = .active) async
    public func refetchQueries(filter: QueryFilter? = nil) async
    public func resetQueries(filter: QueryFilter? = nil)
    public func removeQueries(filter: QueryFilter? = nil)
    public func clear()
    
    // Data access
    public func setQueryData<T: Sendable>(key: any QueryKey, updater: @Sendable (T?) -> T?)
    public func getQueryData<T: Sendable>(key: any QueryKey) -> T?
}
```

#### 2. QueryCache - Storage and Retrieval
```swift
@MainActor
internal final class QueryCache {
    private var queries: [String: WeakQueryInstance] = [:]
    
    // Query management
    func getOrCreateQuery<T: Sendable>(...) -> QueryInstance<T>
    func findAll(filter: QueryFilter?) -> [AnyQueryInstance]
    func removeQueries(filter: QueryFilter?)
    func clear()
}
```

#### 3. QueryInstance - Individual Query State
```swift
@MainActor
internal final class QueryInstance<T: Sendable>: AnyQueryInstance, @unchecked Sendable {
    let state = QueryState<T>()  // @Observable for SwiftUI
    var isActive = false         // Active/inactive tracking
    
    // Query operations
    func fetch() async
    func invalidate()
    func reset()
    func markActive() / markInactive()
}
```

#### Active/Inactive State Tracking
Unlike React Query's observer pattern, SwiftUI Query uses simple active/inactive tracking:

```swift
extension Query {
    public func onAppear() {
        queryInstance?.markActive()
        // Fetch if needed
    }
    
    public func onDisappear() {
        queryInstance?.markInactive()
    }
}
```

#### QueryClient Environment Integration
```swift
extension EnvironmentValues {
    public var queryClient: QueryClient? {
        get { self[QueryClientKey.self] }
        set { self[QueryClientKey.self] = newValue }
    }
}

extension View {
    public func queryClient(_ queryClient: QueryClient) -> some View {
        environment(\.queryClient, queryClient)
    }
}

// Usage
struct App: View {
    let queryClient = QueryClient()
    
    var body: some View {
        ContentView()
            .queryClient(queryClient)
    }
}
```

#### Memory Management with Weak References
```swift
internal struct WeakQueryInstance {
    weak var query: AnyQueryInstance?
    
    init(_ query: AnyQueryInstance) {
        self.query = query
    }
}

// QueryCache automatically cleans up nil references
private func cleanupNilReferences() {
    queries = queries.compactMapValues { weakQuery in
        weakQuery.query != nil ? weakQuery : nil
    }
}
```

### Error Handling with throwOnError

In React, `throwOnError` allows errors to propagate to Error Boundaries. In SwiftUI, we'll use a similar pattern with view modifiers:

#### Error Boundary Implementation
```swift
// Define error reporting environment
struct ReportErrorKey: EnvironmentKey {
    static let defaultValue: (Error) -> Void = { _ in }
}

extension EnvironmentValues {
    var reportError: (Error) -> Void {
        get { self[ReportErrorKey.self] }
        set { self[ReportErrorKey.self] = newValue }
    }
}

// Error Boundary View Modifier
struct ErrorBoundary: ViewModifier {
    @State private var error: Error?
    let resetAction: () -> Void
    
    func body(content: Content) -> some View {
        if let error = error {
            ErrorView(error: error, retry: {
                self.error = nil
                resetAction()
            })
        } else {
            content
                .environment(\.reportError) { error in
                    self.error = error
                }
        }
    }
}

extension View {
    func errorBoundary(reset: @escaping () -> Void) -> some View {
        modifier(ErrorBoundary(resetAction: reset))
    }
}
```

#### Usage with Query
```swift
struct TodoListView: View {
    @Query(
        key: GetTodosQuery(),
        fetch: { try await api.getTodos() },
        throwOnError: true // Errors will propagate to error boundary
    ) var todosQuery
    
    var body: some View {
        List(todosQuery.data ?? []) { todo in
            TodoRow(todo: todo)
        }
        .errorBoundary {
            // Reset action when retry is tapped
            Task { await todosQuery.refetch() }
        }
    }
}

// Nested error boundaries
struct AppView: View {
    var body: some View {
        NavigationView {
            TodoListView()
        }
        .errorBoundary {
            // App-level error recovery
            print("App level error recovery")
        }
    }
}
```

#### throwOnError API Options
```swift
enum ThrowOnError {
    case never
    case always
    case when((Error) -> Bool)
}

// Usage examples
@Query(
    key: GetUserQuery(userId: userId),
    fetch: { try await api.getUser(userId) },
    throwOnError: .always // All errors propagate to error boundary
) var userQuery

@Query(
    key: GetPostsQuery(),
    fetch: { try await api.getPosts() },
    throwOnError: .when { error in
        // Only throw network errors to boundary
        error.isNetworkError || error.isFatalError
    }
) var postsQuery

@Query(
    key: GetSettingsQuery(),
    fetch: { try await api.getSettings() },
    throwOnError: .never // Handle errors inline
) var settingsQuery
```

#### Complete Example with Error Boundary
```swift
struct UserProfileView: View {
    let userId: String
    @Environment(\.reportError) private var reportError
    
    @Query(
        key: GetUserQuery(userId: userId),
        fetch: { try await api.getUser(userId) },
        throwOnError: .when { error in
            // Only throw 500 errors to boundary
            (error as? APIError)?.statusCode == 500
        }
    ) var userQuery
    
    var body: some View {
        ScrollView {
            switch userQuery.status {
            case .loading:
                ProgressView()
            case .success:
                if let user = userQuery.data {
                    UserDetailsView(user: user)
                }
            case .error:
                // Non-500 errors handled inline
                if let error = userQuery.error {
                    InlineErrorView(error: error) {
                        await userQuery.refetch()
                    }
                }
            case .idle:
                EmptyView()
            }
        }
        .navigationTitle("User Profile")
        .errorBoundary {
            userQuery.reset()
        }
    }
}
```

This approach provides:
- Centralized error handling like React Error Boundaries
- Flexible error propagation control
- SwiftUI-native implementation
- Support for nested error boundaries
- Easy reset functionality

### Refetch Behaviors: onAppear and onReconnect

React Query's `refetchOnMount` and `refetchOnReconnect` translate to SwiftUI as view lifecycle and network connectivity triggers:

#### Network Monitoring
```swift
import Network

@Observable
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                
                // Notify when reconnected
                if !wasConnected && self?.isConnected == true {
                    NotificationCenter.default.post(
                        name: .networkReconnected, 
                        object: nil
                    )
                }
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkReconnected = Notification.Name("networkReconnected")
}
```

#### Refetch Trigger Options
```swift
enum RefetchTrigger {
    case never
    case always
    case ifStale
    case when(() -> Bool)
}

struct QueryOptions {
    var staleTime: Duration = .zero
    var gcTime: Duration = .minutes(5)
    
    // React Query equivalents
    var refetchOnAppear: RefetchTrigger = .ifStale        // refetchOnMount
    var refetchOnReconnect: RefetchTrigger = .ifStale     // refetchOnReconnect
    
    // SwiftUI-specific additions
    var refetchOnSceneActive: RefetchTrigger = .ifStale   // App foreground
}
```

#### Usage Examples
```swift
// Static configuration data - minimal refetching
struct ConfigView: View {
    @Query(
        key: GetAppConfigQuery(),
        fetch: { try await api.getAppConfig() },
        options: .init(
            staleTime: .hours(24),
            refetchOnAppear: .never,
            refetchOnReconnect: .never,
            refetchOnSceneActive: .never
        )
    ) var configQuery
    
    var body: some View {
        // UI implementation
    }
}

// Real-time data - aggressive refetching
struct NotificationsView: View {
    @Query(
        key: GetNotificationsQuery(),
        fetch: { try await api.getNotifications() },
        options: .init(
            staleTime: .zero,
            refetchOnAppear: .always,
            refetchOnReconnect: .always,
            refetchOnSceneActive: .always
        )
    ) var notificationsQuery
    
    var body: some View {
        // UI implementation
    }
}

// Smart refetching based on staleness
struct UserProfileView: View {
    let userId: String
    
    @Query(
        key: GetUserQuery(userId: userId),
        fetch: { try await api.getUser(userId) },
        options: .init(
            staleTime: .minutes(5),
            refetchOnAppear: .ifStale,        // Only refetch if data is stale
            refetchOnReconnect: .ifStale,     // Only refetch if stale + reconnected
            refetchOnSceneActive: .never      // Don't refetch on app activation
        )
    ) var userQuery
    
    var body: some View {
        switch userQuery.status {
        case .loading:
            ProgressView()
        case .success:
            if let user = userQuery.data {
                UserDetailsView(user: user)
            }
        case .error:
            ErrorView(error: userQuery.error!) {
                await userQuery.refetch()
            }
        case .idle:
            EmptyView()
        }
    }
}

// Conditional refetching
struct SearchResultsView: View {
    let searchTerm: String
    @State private var isSearching = false
    
    @Query(
        key: SearchQuery(term: searchTerm),
        fetch: { try await api.search(searchTerm) },
        options: .init(
            staleTime: .minutes(10),
            refetchOnAppear: .when { 
                // Only refetch if we're actively searching
                isSearching 
            },
            refetchOnReconnect: .ifStale
        )
    ) var searchQuery
    
    var body: some View {
        // UI implementation
    }
}
```

#### Property Wrapper Lifecycle Integration
```swift
@propertyWrapper
struct Query<T: Sendable>: DynamicProperty {
    @State private var queryState: QueryState<T> = .idle
    @State private var hasAppeared = false
    @State private var hasInitialFetched = false
    
    private let key: any QueryKey
    private let fetch: @Sendable () async throws -> T
    private let options: QueryOptions
    
    var wrappedValue: QueryState<T> {
        queryState
    }
    
    func update() {
        // Only execute initial query if refetchOnAppear is .never
        // Otherwise, let the attach lifecycle handle it
        if !hasInitialFetched {
            hasInitialFetched = true
            handleInitialSetup()
            
            if options.enabled && options.refetchOnAppear == .never {
                executeQuery(isInitial: true)
            }
            
            setupNetworkMonitoring()
        }
    }
    
    private func handleInitialSetup() {
        // Set initial data if provided
        if queryState.status == .idle, let initialData = initialData {
            queryState.setSuccess(data: initialData)
        }
    }
    
    private func setupNetworkMonitoring() {
        // Listen for network reconnection notifications
        NotificationCenter.default.publisher(for: .networkReconnected)
            .sink { _ in
                if shouldRefetch(trigger: options.refetchOnReconnect) {
                    executeQuery(isInitial: false)
                }
            }
    }
    
    private func shouldRefetch(trigger: RefetchTrigger) -> Bool {
        switch trigger {
        case .never: return false
        case .always: return true
        case .ifStale: return queryState.isStale || queryState.status == .idle
        case .when(let condition): return condition()
        }
    }
}

// MARK: - ViewLifecycleAttachable Conformance
extension Query: ViewLifecycleAttachable {
    func onAppear() {
        if !hasAppeared {
            hasAppeared = true
            
            // Execute query based on refetchOnAppear setting
            if options.enabled && shouldRefetch(trigger: options.refetchOnAppear) {
                executeQuery(isInitial: queryState.status == .idle)
            }
        }
    }
    
    func onDisappear() {
        // Future: Cancel in-flight requests, pause intervals
    }
}
```

#### Complete Query Options Structure
```swift
struct QueryOptions {
    // Timing
    var staleTime: Duration = .zero
    var gcTime: Duration = .minutes(5)
    
    // Refetch triggers
    var refetchOnAppear: RefetchTrigger = .ifStale
    var refetchOnReconnect: RefetchTrigger = .ifStale
    var refetchOnSceneActive: RefetchTrigger = .ifStale
    
    // Other options
    var enabled: Bool = true
    var retry: RetryConfig = .default
    var throwOnError: ThrowOnError = .never
    var networkMode: NetworkMode = .online
    
    static let `default` = QueryOptions()
}
```

This provides:
- Automatic refetching on view appear (equivalent to refetchOnMount)
- Network reconnection detection and refetching
- Flexible trigger conditions (never, always, ifStale, custom)
- Seamless integration with SwiftUI view lifecycle

### Query Execution Logic Flow

SwiftUI Query uses a smart execution strategy that depends on the `refetchOnAppear` setting to avoid duplicate fetches and provide predictable behavior:

#### When `refetchOnAppear: .never`
```swift
@Query("config", fetch: fetchConfig, options: QueryOptions(refetchOnAppear: .never))
var configQuery

// Usage: .attach(configQuery) // Optional - no effect since .never
```

**Execution Flow:**
1. ✅ `update()` method executes query immediately on view load
2. ❌ `onAppear()` never triggers query (even with .attach())
3. **Use case:** One-time configuration data that shouldn't refetch

#### When `refetchOnAppear: .always` or `.ifStale`
```swift
@Query("posts", fetch: fetchPosts, options: QueryOptions(refetchOnAppear: .ifStale))
var postsQuery

// Usage: .attach(postsQuery) // Required for query to execute
```

**Execution Flow:**
1. ❌ `update()` method does NOT execute query on view load
2. ✅ `onAppear()` executes query when view appears (via .attach())
3. ✅ Subsequent `onAppear()` calls may refetch based on staleness/settings
4. **Use case:** Dynamic data that should refresh when view appears

#### Comparison Table

| `refetchOnAppear` | Initial Fetch in `update()` | Fetch in `onAppear()` | Requires `.attach()` |
|-------------------|------------------------------|----------------------|---------------------|
| `.never`          | ✅ Yes                      | ❌ Never             | ❌ No               |
| `.always`         | ❌ No                       | ✅ Always            | ✅ Yes              |
| `.ifStale`        | ❌ No                       | ✅ If stale          | ✅ Yes              |
| `.when(condition)`| ❌ No                       | ✅ If condition true | ✅ Yes              |

#### Best Practices

**For static/configuration data:**
```swift
@Query("app-config", fetch: fetchConfig, options: QueryOptions(
    refetchOnAppear: .never,
    staleTime: .hours(24)
))
var configQuery
// No .attach() needed - fetches once automatically
```

**For dynamic data:**
```swift
@Query("user-posts", fetch: fetchPosts, options: QueryOptions(
    refetchOnAppear: .ifStale,
    staleTime: .minutes(5)
))
var postsQuery

// In view:
.attach(postsQuery) // Required for execution
```

**For real-time data:**
```swift
@Query("notifications", fetch: fetchNotifications, options: QueryOptions(
    refetchOnAppear: .always,
    staleTime: .zero
))
var notificationsQuery

// In view:
.attach(notificationsQuery) // Always refetches on appear
```

### Next Steps
1. Define QueryOptions structure
2. Implement Query property wrapper
3. Create QueryKey protocol
4. Build query state management
5. Add lifecycle integration