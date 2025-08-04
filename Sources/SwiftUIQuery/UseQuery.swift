// UseQuery.swift - SwiftUI view component for reactive query management
// Based on TanStack Query's useQuery hook

import SwiftUI
import Perception

// MARK: - Query Result Wrapper

/// Extended query result that includes refetch functionality
/// This provides the same interface as QueryObserverResult but adds refetch
public struct UseQueryResult<TData: Sendable> {
    /// The underlying query observer result
    private let result: QueryObserverResult<TData>
    /// Refetch function from the observer
    private let _refetch: @Sendable (Bool) async throws -> TData?

    init(result: QueryObserverResult<TData>, refetch: @escaping @Sendable (Bool) async throws -> TData?) {
        self.result = result
        self._refetch = refetch
    }

    // Forward all properties from QueryObserverResult
    public var data: TData? { result.data }
    public var error: QueryError? { result.error }
    public var dataUpdateCount: Int { result.dataUpdateCount }
    public var errorUpdateCount: Int { result.errorUpdateCount }
    public var failureCount: Int { result.failureCount }
    public var failureReason: QueryError? { result.failureReason }
    public var dataUpdatedAt: Date? { result.dataUpdatedAt }
    public var errorUpdatedAt: Date? { result.errorUpdatedAt }
    public var isFetching: Bool { result.isFetching }
    public var isPaused: Bool { result.isPaused }
    public var isPending: Bool { result.isPending }
    public var isSuccess: Bool { result.isSuccess }
    public var isError: Bool { result.isError }
    public var isLoading: Bool { result.isLoading }
    public var isRefetching: Bool { result.isRefetching }
    public var isStale: Bool { result.isStale }

    /// Refetch the query
    @discardableResult
    public func refetch(cancelRefetch: Bool = true) async throws -> TData? {
        try await _refetch(cancelRefetch)
    }
}

// MARK: - UseQuery View Component

/// SwiftUI view component that provides reactive query functionality
/// Equivalent to TanStack Query's useQuery hook
/// This is the main interface for using queries in SwiftUI
public struct UseQuery<TData: Sendable, TKey: QueryKey, Content: View>: View {
    // MARK: - Private Properties

    /// Query observer that manages the query lifecycle
    @StateObject private var observer: QueryObserver<TData, TKey>

    /// Current query options (can change during view lifecycle)
    private let options: QueryOptions<TData, TKey>

    /// Optional query client override
    private let queryClient: QueryClient?

    #if DEBUG
        /// Observer access for testing purposes
        var testObserver: QueryObserver<TData, TKey> { observer }
    #endif

    /// Content builder that receives the query result
    private let content: (UseQueryResult<TData>) -> Content

    /// Environment query client (takes precedence over passed client)
    @Environment(\.queryClient) private var environmentQueryClient

    // MARK: - Initialization

    /// Initialize UseQuery with query options and content builder
    /// - Parameters:
    ///   - options: Query configuration options
    ///   - queryClient: Optional query client (uses shared instance if nil)
    ///   - content: View builder that receives the query result
    public init(
        options: QueryOptions<TData, TKey>,
        queryClient: QueryClient? = nil,
        @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
    ) {
        // Store options and client for later use
        self.options = options
        self.queryClient = queryClient
        // Note: Environment client will be resolved in body, use passed client or shared for initial observer
        let client = queryClient ?? QueryClientProvider.shared.queryClient
        self._observer = StateObject(wrappedValue: QueryObserver(client: client, options: options))
        self.content = content
    }

    /// Convenience initializer with explicit parameters
    /// - Parameters:
    ///   - queryKey: Unique identifier for the query
    ///   - queryFn: Function that fetches the data
    ///   - staleTime: Time before data is considered stale (default: 0)
    ///   - gcTime: Time before unused data is garbage collected (default: 5 minutes)
    ///   - enabled: Whether the query should execute automatically (default: true)
    ///   - initialData: Initial data to show while the query loads
    ///   - queryClient: Optional query client (uses shared instance if nil)
    ///   - content: View builder that receives the query result
    public init(
        queryKey: TKey,
        queryFn: @escaping @Sendable (TKey) async throws -> TData,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = 5 * 60,
        enabled: Bool = true,
        initialData: TData? = nil,
        queryClient: QueryClient? = nil,
        @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
    ) {
        let options = QueryOptions<TData, TKey>(
            queryKey: queryKey,
            queryFn: queryFn,
            retryConfig: RetryConfig(),
            networkMode: NetworkMode.online,
            staleTime: staleTime,
            gcTime: gcTime,
            refetchTriggers: RefetchTriggers.default,
            refetchOnAppear: RefetchOnAppear.ifStale,
            initialData: initialData,
            initialDataFunction: nil as InitialDataFunction<TData>?,
            structuralSharing: true,
            meta: nil as QueryMeta?,
            enabled: enabled
        )

        // Store options and client for later use
        self.options = options
        self.queryClient = queryClient
        let client = queryClient ?? QueryClientProvider.shared.queryClient
        self._observer = StateObject(wrappedValue: QueryObserver(client: client, options: options))
        self.content = content
    }

    // MARK: - View Body

    public var body: some View {
        WithPerceptionTracking {
            let useQueryResult = UseQueryResult(
                result: observer.result,
                refetch: { [weak observer] cancelRefetch in
                    guard let observer else { return nil }
                    return try await observer.refetch(cancelRefetch: cancelRefetch).value
                }
            )
            VStack {
                content(useQueryResult)
            }
        }
        .onAppear {
            // Use environment client if available, otherwise keep current observer
//            let finalClient = environmentQueryClient ?? queryClient ?? QueryClientProvider.shared.queryClient
//            if observer.client !== finalClient {
//                // Create new observer with correct client
//                let newObserver = QueryObserver(client: finalClient, options: options)
//                observer = newObserver
//            }

            // Update observer options to current options
            observer.setOptions(options)
            observer.subscribe()
        }
        .onDisappear {
            observer.unsubscribe()
        }
        .onChange(of: options.queryKey) { newKey in
            let newOptions = QueryOptions<TData, TKey>(
                queryKey: newKey,
                queryFn: options.queryFn,
                retryConfig: options.retryConfig,
                networkMode: options.networkMode,
                staleTime: options.staleTime,
                gcTime: options.gcTime,
                refetchTriggers: options.refetchTriggers,
                refetchOnAppear: options.refetchOnAppear,
                initialData: options.initialData,
                initialDataFunction: options.initialDataFunction,
                structuralSharing: options.structuralSharing,
                meta: options.meta,
                enabled: options.enabled
            )
            observer.setOptions(newOptions)
        }
        .onChange(of: options.enabled) { newEnabled in
            // Update observer options when enabled state changes
            // Create new options using the new enabled value
            let newOptions = QueryOptions<TData, TKey>(
                queryKey: options.queryKey,
                queryFn: options.queryFn,
                retryConfig: options.retryConfig,
                networkMode: options.networkMode,
                staleTime: options.staleTime,
                gcTime: options.gcTime,
                refetchTriggers: options.refetchTriggers,
                refetchOnAppear: options.refetchOnAppear,
                initialData: options.initialData,
                initialDataFunction: options.initialDataFunction,
                structuralSharing: options.structuralSharing,
                meta: options.meta,
                enabled: newEnabled // Use the new enabled value from closure
            )
            observer.setOptions(newOptions)
        }
    }
}

// MARK: - Convenience Extensions

extension UseQuery {
    /// Create UseQuery with string-based query key
    /// - Parameters:
    ///   - queryKey: String identifier for the query
    ///   - queryFn: Function that fetches the data
    ///   - staleTime: Time before data is considered stale (default: 0)
    ///   - gcTime: Time before unused data is garbage collected (default: 5 minutes)
    ///   - enabled: Whether the query should execute automatically (default: true)
    ///   - initialData: Initial data to show while the query loads
    ///   - queryClient: Optional query client (uses shared instance if nil)
    ///   - content: View builder that receives the query result
    public init(
        queryKey: String,
        queryFn: @escaping @Sendable (String) async throws -> TData,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = 5 * 60,
        enabled: Bool = true,
        initialData: TData? = nil,
        queryClient: QueryClient? = nil,
        @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
    ) where TKey == String {
        let options = QueryOptions<TData, String>(
            queryKey: queryKey,
            queryFn: queryFn,
            retryConfig: RetryConfig(),
            networkMode: NetworkMode.online,
            staleTime: staleTime,
            gcTime: gcTime,
            refetchTriggers: RefetchTriggers.default,
            refetchOnAppear: RefetchOnAppear.ifStale,
            initialData: initialData,
            initialDataFunction: nil as InitialDataFunction<TData>?,
            structuralSharing: true,
            meta: nil as QueryMeta?,
            enabled: enabled
        )

        // Store options and client for later use
        self.options = options
        self.queryClient = queryClient
        let client = queryClient ?? QueryClientProvider.shared.queryClient
        self._observer = StateObject(wrappedValue: QueryObserver(client: client, options: options))
        self.content = content
    }

    /// Create UseQuery with array-based query key
    /// - Parameters:
    ///   - queryKey: Array identifier for the query
    ///   - queryFn: Function that fetches the data
    ///   - staleTime: Time before data is considered stale (default: 0)
    ///   - gcTime: Time before unused data is garbage collected (default: 5 minutes)
    ///   - enabled: Whether the query should execute automatically (default: true)
    ///   - initialData: Initial data to show while the query loads
    ///   - queryClient: Optional query client (uses shared instance if nil)
    ///   - content: View builder that receives the query result
    public init(
        queryKey: [String],
        queryFn: @escaping @Sendable ([String]) async throws -> TData,
        staleTime: TimeInterval = 0,
        gcTime: TimeInterval = 5 * 60,
        enabled: Bool = true,
        initialData: TData? = nil,
        queryClient: QueryClient? = nil,
        @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
    ) where TKey == [String] {
        let options = QueryOptions<TData, [String]>(
            queryKey: queryKey,
            queryFn: queryFn,
            retryConfig: RetryConfig(),
            networkMode: NetworkMode.online,
            staleTime: staleTime,
            gcTime: gcTime,
            refetchTriggers: RefetchTriggers.default,
            refetchOnAppear: RefetchOnAppear.ifStale,
            initialData: initialData,
            initialDataFunction: nil as InitialDataFunction<TData>?,
            structuralSharing: true,
            meta: nil as QueryMeta?,
            enabled: enabled
        )

        // Store options and client for later use
        self.options = options
        self.queryClient = queryClient
        let client = queryClient ?? QueryClientProvider.shared.queryClient
        self._observer = StateObject(wrappedValue: QueryObserver(client: client, options: options))
        self.content = content
    }
}

// MARK: - Preview Helpers

#if DEBUG
    extension UseQuery {
        /// Create a UseQuery for SwiftUI previews with mock data
        /// - Parameters:
        ///   - queryKey: Mock query key
        ///   - mockData: Static data to return
        ///   - content: View builder that receives the query result
        public static func preview(
            queryKey: TKey,
            mockData: TData,
            @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
        ) -> UseQuery<TData, TKey, Content> {
            let options = QueryOptions<TData, TKey>(
                queryKey: queryKey,
                queryFn: { _ in mockData },
                retryConfig: RetryConfig(),
                networkMode: NetworkMode.online,
                staleTime: 0,
                gcTime: 5 * 60,
                refetchTriggers: RefetchTriggers.default,
                refetchOnAppear: RefetchOnAppear.ifStale,
                initialData: nil as TData?,
                initialDataFunction: nil as InitialDataFunction<TData>?,
                structuralSharing: true,
                meta: nil as QueryMeta?,
                enabled: true
            )
            return UseQuery(options: options, content: content)
        }

        /// Create a UseQuery for SwiftUI previews with loading state
        /// - Parameters:
        ///   - queryKey: Mock query key
        ///   - content: View builder that receives the query result
        public static func previewLoading(
            queryKey: TKey,
            @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
        ) -> UseQuery<TData, TKey, Content> {
            let options = QueryOptions<TData, TKey>(
                queryKey: queryKey,
                queryFn: { _ in
                    // Simulate loading by never completing
                    try await Task.sleep(nanoseconds: UInt64.max)
                    throw QueryError.cancelled
                },
                retryConfig: RetryConfig(),
                networkMode: NetworkMode.online,
                staleTime: 0,
                gcTime: 5 * 60,
                refetchTriggers: RefetchTriggers.default,
                refetchOnAppear: RefetchOnAppear.ifStale,
                initialData: nil as TData?,
                initialDataFunction: nil as InitialDataFunction<TData>?,
                structuralSharing: true,
                meta: nil as QueryMeta?,
                enabled: true
            )
            return UseQuery(options: options, content: content)
        }

        /// Create a UseQuery for SwiftUI previews with error state
        /// - Parameters:
        ///   - queryKey: Mock query key
        ///   - error: Error to simulate
        ///   - content: View builder that receives the query result
        public static func previewError(
            queryKey: TKey,
            error: QueryError = QueryError.networkError(URLError(.notConnectedToInternet)),
            @ViewBuilder content: @escaping (UseQueryResult<TData>) -> Content
        ) -> UseQuery<TData, TKey, Content> {
            let options = QueryOptions<TData, TKey>(
                queryKey: queryKey,
                queryFn: { _ in throw error },
                retryConfig: RetryConfig(),
                networkMode: NetworkMode.online,
                staleTime: 0,
                gcTime: 5 * 60,
                refetchTriggers: RefetchTriggers.default,
                refetchOnAppear: RefetchOnAppear.ifStale,
                initialData: nil as TData?,
                initialDataFunction: nil as InitialDataFunction<TData>?,
                structuralSharing: true,
                meta: nil as QueryMeta?,
                enabled: true
            )
            return UseQuery(options: options, content: content)
        }
    }
#endif

// MARK: - Environment Support

/// Environment key for providing custom QueryClient
private struct QueryClientEnvironmentKey: EnvironmentKey {
    static let defaultValue: QueryClient? = nil
}

extension EnvironmentValues {
    /// Environment value for injecting a custom QueryClient
    public var queryClient: QueryClient? {
        get { self[QueryClientEnvironmentKey.self] }
        set { self[QueryClientEnvironmentKey.self] = newValue }
    }
}

/// View modifier to provide a QueryClient to the environment
public struct QueryClientProviderModifier: ViewModifier {
    let queryClient: QueryClient?

    private var resolvedQueryClient: QueryClient {
        queryClient ?? QueryClientProvider.shared.queryClient
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.queryClient, resolvedQueryClient)
            .onAppear {
                resolvedQueryClient.mount()
            }
            .onDisappear {
                resolvedQueryClient.unmount()
            }
    }
}

extension View {
    /// Provide a QueryClient to all child views
    /// - Parameter queryClient: The QueryClient to provide
    /// - Returns: Modified view with QueryClient in environment
    public func queryClient(_ queryClient: QueryClient? = nil) -> some View {
        modifier(QueryClientProviderModifier(queryClient: queryClient))
    }
}
