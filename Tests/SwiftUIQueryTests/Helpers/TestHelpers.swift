import Testing
import SwiftUI
@testable import SwiftUIQuery

// MARK: - Test Data Models

struct TestUser: Sendable, Codable, Equatable {
    let id: String
    let name: String
    let email: String
}

struct TestPost: Sendable, Codable, Equatable {
    let id: String
    let title: String
    let content: String
    let userId: String
}

// MARK: - Test Query Keys

enum TestQueryKey: Hashable, Sendable {
    case user(id: String)
    case posts
    case post(id: String)
    case userPosts(userId: String)
}

// MARK: - Mock Network Client

@MainActor
final class MockNetworkClient: @unchecked Sendable {
    var responses: [String: Any] = [:]
    var errors: [String: Error] = [:]
    var delay: Duration = .zero
    var callCount: [String: Int] = [:]
    
    func setResponse<T>(for key: String, response: T) {
        responses[key] = response
    }
    
    func setError(for key: String, error: Error) {
        errors[key] = error
    }
    
    func fetch<T: Sendable>(_ key: String) async throws -> T {
        // Track call count
        callCount[key, default: 0] += 1
        
        // Simulate network delay
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        
        // Return error if set
        if let error = errors[key] {
            throw error
        }
        
        // Return response if available
        guard let response = responses[key] as? T else {
            throw TestError.noResponse
        }
        
        return response
    }
    
    func reset() {
        responses.removeAll()
        errors.removeAll()
        callCount.removeAll()
        delay = .zero
    }
}

// MARK: - Test Errors

enum TestError: Error, Equatable, CustomStringConvertible {
    case noResponse
    case networkError
    case serverError(code: Int)
    case customError(String)
    
    var description: String {
        switch self {
        case .noResponse:
            return "No response configured"
        case .networkError:
            return "Network error"
        case .serverError(let code):
            return "Server error: \(code)"
        case .customError(let message):
            return message
        }
    }
}

// MARK: - Test Assertions for Swift Testing

/// Wait for a condition to be met within a timeout period
func waitFor(
    _ condition: @escaping () async -> Bool,
    timeout: Duration = .seconds(1),
    checkInterval: Duration = .milliseconds(10)
) async throws {
    let deadline = ContinuousClock.now + timeout
    
    while ContinuousClock.now < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(for: checkInterval)
    }
    
    Issue.record("Condition not met within timeout")
}

/// Assert that a type conforms to Sendable
func assertSendable<T: Sendable>(_ type: T.Type) {
    // This is a compile-time check - T must conform to Sendable
}

/// Perform concurrent operations and collect results
func performConcurrentOperations<T: Sendable>(
    count: Int = 100,
    operation: @escaping @Sendable () async throws -> T
) async throws -> [T] {
    try await withThrowingTaskGroup(of: T.self) { group in
        for _ in 0..<count {
            group.addTask {
                try await operation()
            }
        }
        
        var results: [T] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}

// MARK: - Custom Test Traits

struct TimeoutTrait: TestTrait {
    let timeout: Duration
}

extension TestTrait where Self == TimeoutTrait {
    static func timeout(_ duration: Duration) -> Self {
        TimeoutTrait(timeout: duration)
    }
}

// MARK: - Test Environment Setup

@MainActor
struct TestEnvironment {
    let mockClient: MockNetworkClient
    
    init() {
        self.mockClient = MockNetworkClient()
    }
    
    func reset() {
        mockClient.reset()
    }
}