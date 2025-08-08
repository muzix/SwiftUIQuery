import Foundation

/// Event types for cache notifications
/// Equivalent to TanStack Query's cache event system
public enum QueryCacheEvent: Sendable {
    case added(queryHash: String)
    case removed(queryHash: String)
    case updated(queryHash: String)
    case cleared
}

/// Listener function type for cache events
public typealias QueryCacheListener = @Sendable (QueryCacheEvent) -> Void

/// Type-erased query wrapper for storing different query types in the same cache
@MainActor
public protocol AnyQuery {
    var queryHash: String { get }
    var isStale: Bool { get }
    var lastUpdated: Date? { get }
    var isActive: Bool { get }
    var gcTime: TimeInterval { get }
    var isEligibleForGC: Bool { get }
}

/// Thread-safe cache for storing and managing query instances
/// Equivalent to TanStack Query's QueryCache with Observer pattern
/// Note: @MainActor is currently required because AnyQuery protocol is @MainActor
/// In a future refactor, we could make QueryCache truly thread-safe with an actor-based design
@MainActor
public final class QueryCache {
    /// Internal dictionary storing queries by their hash
    private var queries: [String: AnyQuery] = [:]

    /// Set of event listeners for cache notifications
    private var listeners: Set<QueryCacheListenerWrapper> = []

    /// Mutex for coordinating thread-safe operations
    private let mutex = Mutex()

    public init() {}

    // MARK: - Query Management

    /// Add a query to the cache
    /// Notifies listeners of the addition
    public func add(_ query: AnyQuery) {
        let queryHash = query.queryHash
        queries[queryHash] = query
        notify(.added(queryHash: queryHash))
    }

    /// Remove a query from the cache
    /// Notifies listeners of the removal
    public func remove(_ query: AnyQuery) {
        let queryHash = query.queryHash
        queries.removeValue(forKey: queryHash)
        notify(.removed(queryHash: queryHash))
    }

    /// Get a query by its hash
    public func get(queryHash: String) -> AnyQuery? {
        queries[queryHash]
    }

    /// Check if a query exists in the cache
    public func has(queryHash: String) -> Bool {
        queries[queryHash] != nil
    }

    /// Get all queries in the cache
    public var allQueries: [AnyQuery] {
        Array(queries.values)
    }

    /// Clear all queries from the cache
    /// Notifies listeners of the clear operation
    public func clear() {
        queries.removeAll()
        notify(.cleared)
    }

    /// Find queries matching the given predicate
    public func findAll(matching predicate: (AnyQuery) -> Bool) -> [AnyQuery] {
        queries.values.filter(predicate)
    }

    /// Find the first query matching the given predicate
    public func find(matching predicate: (AnyQuery) -> Bool) -> AnyQuery? {
        queries.values.first(where: predicate)
    }

    // MARK: - Observer Pattern

    /// Subscribe to cache events
    /// Returns a function to unsubscribe
    public func subscribe(_ listener: @escaping QueryCacheListener) -> () -> Void {
        let wrapper = QueryCacheListenerWrapper(listener: listener)
        listeners.insert(wrapper)

        return { [weak self] in
            self?.listeners.remove(wrapper)
        }
    }

    /// Notify all listeners of a cache event
    private func notify(_ event: QueryCacheEvent) {
        for listener in listeners {
            listener.listener(event)
        }
    }

    // MARK: - Thread-Safe Operations

    /// Execute an operation with thread-safe access to the cache
    public func withLock<T: Sendable>(_ operation: @MainActor @Sendable () async throws -> T) async rethrows -> T {
        try await mutex.withLock {
            try await operation()
        }
    }

    // MARK: - Cache Statistics

    /// Get the number of queries in the cache
    public var count: Int {
        queries.count
    }

    /// Check if the cache is empty
    public var isEmpty: Bool {
        queries.isEmpty
    }

    /// Get all query hashes currently in the cache
    public var queryHashes: Set<String> {
        Set(queries.keys)
    }
}

/// Wrapper for query cache listeners to make them Hashable for Set storage
private struct QueryCacheListenerWrapper: Hashable {
    let id = UUID()
    let listener: QueryCacheListener

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
