//
//  PokemonSearchFetcher.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUIQuery

// MARK: - Pokemon Search Fetcher

/// Fetcher for searching Pokemon by name with dynamic input
@MainActor
public final class PokemonSearchFetcher: FetchProtocol {
    // MARK: - Properties

    /// The search term to fetch (can change dynamically)
    public var searchTerm = ""

    /// Base URL for Pokemon API
    private let baseURL = "https://pokeapi.co/api/v2/pokemon/"

    // MARK: - Initialization

    public init(searchTerm: String = "") {
        self.searchTerm = searchTerm
    }

    // MARK: - FetchProtocol

    public func fetch() async throws -> Pokemon {
        // Use the current search term (dynamic!)
        let cleanTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanTerm.isEmpty else {
            throw PokemonSearchError.emptySearchTerm
        }

        // Validate search term (basic validation)
        guard cleanTerm.count >= 2 else {
            throw PokemonSearchError.searchTermTooShort
        }

        guard let url = URL(string: "\(baseURL)\(cleanTerm)") else {
            throw PokemonSearchError.invalidResponse
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PokemonSearchError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                return try JSONDecoder().decode(Pokemon.self, from: data)
            case 404:
                throw PokemonSearchError.pokemonNotFound(cleanTerm)
            default:
                throw PokemonSearchError.serverError(httpResponse.statusCode)
            }
        } catch let error as DecodingError {
            throw PokemonSearchError.decodingFailed(error)
        } catch let error as PokemonSearchError {
            throw error
        } catch {
            throw PokemonSearchError.networkError(error)
        }
    }
}

// MARK: - Pokemon Search Error

public enum PokemonSearchError: Error, LocalizedError {
    case emptySearchTerm
    case searchTermTooShort
    case pokemonNotFound(String)
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    case decodingFailed(DecodingError)

    public var errorDescription: String? {
        switch self {
        case .emptySearchTerm:
            return "Please enter a Pokemon name to search"
        case .searchTermTooShort:
            return "Search term must be at least 2 characters long"
        case let .pokemonNotFound(name):
            return "Pokemon '\(name)' not found. Try checking the spelling!"
        case .invalidResponse:
            return "Invalid response from Pokemon API"
        case let .serverError(code):
            return "Server error (HTTP \(code)). Please try again later."
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .decodingFailed:
            return "Failed to parse Pokemon data from API"
        }
    }
}

// MARK: - Advanced Pokemon Search Fetcher

/// Advanced fetcher with additional search options
@MainActor
public final class AdvancedPokemonSearchFetcher: FetchProtocol {
    // MARK: - Search Options

    public var searchTerm = ""
    public var includeForms = true
    public var cacheLocally = true

    // Internal cache
    private var localCache: [String: Pokemon] = [:]

    // MARK: - Initialization

    public init(searchTerm: String = "", includeForms: Bool = true, cacheLocally: Bool = true) {
        self.searchTerm = searchTerm
        self.includeForms = includeForms
        self.cacheLocally = cacheLocally
    }

    // MARK: - FetchProtocol

    public func fetch() async throws -> Pokemon {
        let cleanTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanTerm.isEmpty else {
            throw PokemonSearchError.emptySearchTerm
        }

        // Check local cache first if enabled
        if cacheLocally, let cached = localCache[cleanTerm] {
            print("🎯 Returning cached result for '\(cleanTerm)'")
            return cached
        }

        print("🌐 Fetching '\(cleanTerm)' from API (includeForms: \(includeForms))")

        let baseURL = "https://pokeapi.co/api/v2/pokemon/"
        guard let url = URL(string: "\(baseURL)\(cleanTerm)") else {
            throw PokemonSearchError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PokemonSearchError.pokemonNotFound(cleanTerm)
        }

        let pokemon = try JSONDecoder().decode(Pokemon.self, from: data)

        // Cache locally if enabled
        if cacheLocally {
            localCache[cleanTerm] = pokemon
        }

        return pokemon
    }

    // MARK: - Cache Management

    public func clearLocalCache() {
        localCache.removeAll()
        print("🗑️ Local Pokemon cache cleared")
    }

    public func getCacheSize() -> Int {
        localCache.count
    }
}
