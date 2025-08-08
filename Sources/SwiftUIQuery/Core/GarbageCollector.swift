import Foundation

// MARK: - Garbage Collector

/// Centralized garbage collector that runs at configurable intervals
/// to clean up inactive queries across all caches
@MainActor
public final class GarbageCollector {
    /// Shared instance for global garbage collection
    public static let shared = GarbageCollector()

    /// Default garbage collection interval (30 seconds)
    public static let defaultInterval: TimeInterval = 30

    /// Current garbage collection interval
    public private(set) var interval: TimeInterval

    /// Timer for periodic garbage collection
    private var timer: Timer?

    /// Set of query caches to monitor
    private var caches: Set<ObjectIdentifier> = []

    /// Weak references to query caches
    private var cacheReferences: [ObjectIdentifier: WeakQueryCacheRef] = [:]

    /// Whether garbage collection is currently running
    private var isRunning = false

    private init(interval: TimeInterval = defaultInterval) {
        self.interval = interval
    }

    /// Configure garbage collection interval
    /// - Parameter interval: Time interval between GC runs (in seconds)
    public func configure(interval: TimeInterval) {
        self.interval = interval

        // Restart timer with new interval if currently running
        if isRunning {
            stop()
            start()
        }
    }

    /// Start periodic garbage collection
    public func start() {
        guard !isRunning else { return }

        isRunning = true

        #if DEBUG
            print("🗑️ SwiftUI Query: Starting GarbageCollector with \(interval)s interval")
        #endif

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.collectGarbage()
            }
        }
    }

    /// Stop periodic garbage collection
    public func stop() {
        guard isRunning else { return }

        isRunning = false
        timer?.invalidate()
        timer = nil

        #if DEBUG
            print("🗑️ SwiftUI Query: Stopping GarbageCollector")
        #endif
    }

    /// Register a query cache for garbage collection monitoring
    /// - Parameter cache: Query cache to monitor
    public func register(_ cache: QueryCache) {
        let id = ObjectIdentifier(cache)
        caches.insert(id)
        cacheReferences[id] = WeakQueryCacheRef(cache: cache)

        // Start GC if this is the first cache and we're not running
        if caches.count == 1, !isRunning {
            start()
        }
    }

    /// Unregister a query cache from garbage collection monitoring
    /// - Parameter cache: Query cache to stop monitoring
    public func unregister(_ cache: QueryCache) {
        let id = ObjectIdentifier(cache)
        caches.remove(id)
        cacheReferences.removeValue(forKey: id)

        // Stop GC if no caches remain
        if caches.isEmpty {
            stop()
        }
    }

    /// Manually trigger garbage collection across all registered caches
    public func collectGarbage() {
        // Clean up deallocated cache references first
        cleanupDeadReferences()

        // Early return if no caches to process
        guard !cacheReferences.isEmpty else { return }

        let startTime = Date()
        var totalQueries = 0
        var removedQueries = 0

        // Collect garbage from all live caches
        for (id, cacheRef) in cacheReferences {
            guard let cache = cacheRef.cache else {
                // Cache was deallocated, remove reference
                caches.remove(id)
                cacheReferences.removeValue(forKey: id)
                continue
            }

            let queries = cache.allQueries
            totalQueries += queries.count

            // Find inactive queries eligible for removal
            let inactiveQueries = queries.filter { query in
                isEligibleForRemoval(query, cache: cache)
            }

            // Remove inactive queries
            for query in inactiveQueries {
                cache.remove(query)
                removedQueries += 1

                #if DEBUG
                    print("🗑️ SwiftUI Query: GC removed inactive query \(query.queryHash)")
                #endif
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        #if DEBUG
            if removedQueries > 0 {
                print(
                    "🗑️ SwiftUI Query: GC completed - removed \(removedQueries)/\(totalQueries) queries in \(String(format: "%.2f", duration * 1000))ms"
                )
            }
        #endif
    }

    /// Check if a query is eligible for garbage collection
    /// - Parameters:
    ///   - query: Query to check
    ///   - cache: Cache containing the query
    /// - Returns: true if query should be removed
    private func isEligibleForRemoval(_ query: AnyQuery, cache: QueryCache) -> Bool {
        // Use the query's own GC eligibility logic
        query.isEligibleForGC
    }

    /// Clean up references to deallocated caches
    private func cleanupDeadReferences() {
        let deadReferences = cacheReferences.compactMap { id, ref -> ObjectIdentifier? in
            ref.cache == nil ? id : nil
        }

        for id in deadReferences {
            caches.remove(id)
            cacheReferences.removeValue(forKey: id)
        }
    }
}

/// Weak reference wrapper for query caches
private class WeakQueryCacheRef {
    weak var cache: QueryCache?

    init(cache: QueryCache) {
        self.cache = cache
    }
}
