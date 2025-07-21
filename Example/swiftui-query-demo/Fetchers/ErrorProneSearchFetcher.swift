//
//  ErrorProneSearchFetcher.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUIQuery

// MARK: - Error Prone Search Fetcher

/// Fetcher that demonstrates error boundary behavior with FetchProtocol
@MainActor
public final class ErrorProneSearchFetcher: ObservableObject, FetchProtocol {
    
    // MARK: - Properties
    
    /// The search term (can cause different types of errors)
    @Published public var searchTerm: String = ""
    
    /// Whether to simulate network errors
    @Published public var simulateNetworkError: Bool = false
    
    /// Whether to simulate server errors
    @Published public var simulateServerError: Bool = false
    
    // MARK: - Initialization
    
    public init(searchTerm: String = "") {
        self.searchTerm = searchTerm
    }
    
    // MARK: - FetchProtocol
    
    public func fetch() async throws -> SearchResult {
        let cleanTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        // Simulate different error conditions based on search term
        if simulateNetworkError {
            throw SearchError.networkFailure("Simulated network connection failed")
        }
        
        if simulateServerError {
            throw SearchError.serverError(500, "Internal server error")
        }
        
        if cleanTerm.isEmpty {
            throw SearchError.emptyQuery
        }
        
        if cleanTerm.count < 2 {
            throw SearchError.queryTooShort(cleanTerm)
        }
        
        // Special error terms for demo
        switch cleanTerm.lowercased() {
        case "error", "fail":
            throw SearchError.demoError("You searched for '\(cleanTerm)' - this always fails!")
        case "network":
            throw SearchError.networkFailure("Network error triggered by search term")
        case "server":
            throw SearchError.serverError(503, "Server error triggered by search term")
        case "timeout":
            throw SearchError.timeout("Request timed out for term: \(cleanTerm)")
        default:
            break
        }
        
        // Success case - return mock search result
        return SearchResult(
            query: cleanTerm,
            results: mockResults(for: cleanTerm),
            timestamp: Date()
        )
    }
    
    // MARK: - Mock Results
    
    private func mockResults(for term: String) -> [String] {
        let allResults = [
            "Apple", "Banana", "Cherry", "Date", "Elderberry",
            "Fig", "Grape", "Honeydew", "Ice Apple", "Jackfruit"
        ]
        
        return allResults.filter { $0.lowercased().contains(term.lowercased()) }
    }
}

// MARK: - Search Result

public struct SearchResult: Sendable, Codable {
    public let query: String
    public let results: [String]
    public let timestamp: Date
    
    public init(query: String, results: [String], timestamp: Date) {
        self.query = query
        self.results = results
        self.timestamp = timestamp
    }
}

// MARK: - Search Errors

public enum SearchError: Error, LocalizedError, Equatable {
    case emptyQuery
    case queryTooShort(String)
    case networkFailure(String)
    case serverError(Int, String)
    case timeout(String)
    case demoError(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .queryTooShort(let term):
            return "Search term '\(term)' is too short (minimum 2 characters)"
        case .networkFailure(let message):
            return "Network error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .timeout(let message):
            return "Request timeout: \(message)"
        case .demoError(let message):
            return "Demo error: \(message)"
        }
    }
    
    /// Returns true if this is a network-level error that should bubble to error boundary
    public var isNetworkError: Bool {
        switch self {
        case .networkFailure, .serverError, .timeout:
            return true
        case .emptyQuery, .queryTooShort, .demoError:
            return false
        }
    }
    
    /// Returns true if this is a validation error that should be handled inline
    public var isValidationError: Bool {
        switch self {
        case .emptyQuery, .queryTooShort:
            return true
        case .networkFailure, .serverError, .timeout, .demoError:
            return false
        }
    }
}