import Foundation

// MARK: - Cache Infrastructure

/// Thread-safe mutex actor for coordinating cache operations
/// Provides synchronization for concurrent access to shared cache state
public actor Mutex {
    private var isLocked = false
    private var waitingTasks: [CheckedContinuation<Void, Never>] = []

    /// Acquire the mutex lock
    /// Suspends the calling task until the lock is available
    public func lock() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waitingTasks.append(continuation)
        }
    }

    /// Release the mutex lock
    /// Resumes the next waiting task if any
    public func unlock() {
        guard isLocked else { return }

        if let nextTask = waitingTasks.first {
            waitingTasks.removeFirst()
            nextTask.resume()
        } else {
            isLocked = false
        }
    }

    /// Execute a critical section with automatic lock/unlock
    /// Ensures the lock is always released even if the operation throws
    public func withLock<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await lock()
        defer {
            Task { self.unlock() }
        }
        return try await operation()
    }

    /// Check if the mutex is currently locked (for testing purposes)
    public nonisolated var isCurrentlyLocked: Bool {
        get async {
            await isLocked
        }
    }
}
