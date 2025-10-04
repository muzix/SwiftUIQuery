// QueryLogger.swift - Centralized logging system for SwiftUI Query cache operations
// Provides a single toggle to enable/disable all cache logging
// swiftlint:disable no_print_statements

import Foundation

/// Centralized logging system for SwiftUI Query cache operations
/// Provides fine-grained control over different types of cache logging
@MainActor
public final class QueryLogger {
    /// Shared logger instance
    public static let shared = QueryLogger()

    // MARK: - Global Toggle

    /// Master switch to enable/disable all cache logging
    /// Set this to false in production to disable all cache logging
    public var isEnabled = false

    // MARK: - Granular Controls

    /// Enable/disable QueryClient cache operation logging
    public var logQueryClient = true

    /// Enable/disable Query state change logging
    public var logQuery = true

    /// Enable/disable QueryObserver cache interaction logging
    public var logQueryObserver = true

    /// Enable/disable GarbageCollector logging
    public var logGarbageCollector = true

    private init() {}

    // MARK: - Logging Methods

    /// Log QueryClient cache hits
    func logCacheHit(hash: String) {
        guard isEnabled, logQueryClient else { return }
        print("🎯 Query cache hit for key hash: \(hash)")
    }

    /// Log QueryClient cache misses
    func logCacheMiss(hash: String) {
        guard isEnabled, logQueryClient else { return }
        print("📝 Query cache miss for key hash: \(hash) - creating new query")
    }

    /// Log QueryClient data cache hits
    func logDataCacheHit(hash: String) {
        guard isEnabled, logQueryClient else { return }
        print("🎯 Query data cache hit for key hash: \(hash)")
    }

    /// Log QueryClient data cache misses
    func logDataCacheMiss(hash: String) {
        guard isEnabled, logQueryClient else { return }
        print("❌ Query data not found for key hash: \(hash)")
    }

    /// Log QueryClient state cache hits
    func logStateCacheHit(hash: String) {
        guard isEnabled, logQueryClient else { return }
        print("🎯 Query state cache hit for key hash: \(hash)")
    }

    /// Log QueryClient state cache misses
    func logStateCacheMiss(hash: String) {
        guard isEnabled, logQueryClient else { return }
        print("❌ Query state not found for key hash: \(hash)")
    }

    /// Log Query data being set
    func logQueryDataSet(hash: String) {
        guard isEnabled, logQuery else { return }
        print("💾 Setting data for query hash: \(hash)")
    }

    /// Log Query state changes (data)
    func logQueryStateDataChanged(hash: String) {
        guard isEnabled, logQuery else { return }
        print("🔄 Query state updated (data changed) for hash: \(hash)")
    }

    /// Log Query state changes (status)
    func logQueryStateStatusChanged(hash: String) {
        guard isEnabled, logQuery else { return }
        print("🔄 Query state updated (status changed) for hash: \(hash)")
    }

    /// Log Query invalidation
    func logQueryInvalidation(hash: String) {
        guard isEnabled, logQuery else { return }
        print("🗑️ Invalidating query cache for hash: \(hash)")
    }

    /// Log Query reset
    func logQueryReset(hash: String) {
        guard isEnabled, logQuery else { return }
        print("🔄 Resetting query cache for hash: \(hash)")
    }

    /// Log QueryObserver switching to new query
    func logObserverSwitchQuery(hash: String) {
        guard isEnabled, logQueryObserver else { return }
        print("🔄 QueryObserver switching to query hash: \(hash)")
    }

    /// Log QueryObserver reusing existing query
    func logObserverReuseQuery(hash: String) {
        guard isEnabled, logQueryObserver else { return }
        print("👁️ QueryObserver reusing existing query hash: \(hash)")
    }

    /// Log QueryObserver reading query state
    func logObserverReadState(hash: String) {
        guard isEnabled, logQueryObserver else { return }
        print("📊 QueryObserver reading query state for hash: \(hash)")
    }

    // MARK: - Garbage Collector Logging

    /// Log GarbageCollector starting
    func logGCStart(interval: TimeInterval) {
        guard isEnabled, logGarbageCollector else { return }
        print("🗑️ SwiftUI Query: Starting GarbageCollector with \(interval)s interval")
    }

    /// Log GarbageCollector stopping
    func logGCStop() {
        guard isEnabled, logGarbageCollector else { return }
        print("🗑️ SwiftUI Query: Stopping GarbageCollector")
    }

    /// Log GC cancelled for active query
    func logGCCancelled(hash: String) {
        guard isEnabled, logGarbageCollector else { return }
        print("🗑️ SwiftUI Query: GC cancelled for \(hash) - Query is active or not eligible")
    }

    /// Log GC executing for query
    func logGCExecuting(hash: String) {
        guard isEnabled, logGarbageCollector else { return }
        print("🗑️ SwiftUI Query: Executing GC for \(hash)")
    }

    /// Log GC removing query
    func logGCRemoving(hash: String, reason: String) {
        guard isEnabled, logGarbageCollector else { return }
        print("🗑️ SwiftUI Query: GC removing \(hash) - \(reason)")
    }
}

// MARK: - Public API Extensions

extension QueryLogger {
    /// Enable all cache logging (convenience method)
    public func enableAll() {
        isEnabled = true
        logQueryClient = true
        logQuery = true
        logQueryObserver = true
        logGarbageCollector = true
    }

    /// Disable all cache logging (convenience method)
    public func disableAll() {
        isEnabled = false
    }

    /// Enable only QueryClient logging
    public func enableQueryClientOnly() {
        isEnabled = true
        logQueryClient = true
        logQuery = false
        logQueryObserver = false
    }

    /// Enable only Query logging
    public func enableQueryOnly() {
        isEnabled = true
        logQueryClient = false
        logQuery = true
        logQueryObserver = false
    }

    /// Enable only QueryObserver logging
    public func enableQueryObserverOnly() {
        isEnabled = true
        logQueryClient = false
        logQuery = false
        logQueryObserver = true
    }
}

// swiftlint:enable no_print_statements
