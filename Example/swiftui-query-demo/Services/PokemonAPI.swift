//
//  PokemonAPI.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation

// MARK: - Pokemon Data Models

struct Pokemon: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let sprites: Sprites
    let types: [PokemonType]
    let stats: [Stat]

    struct Sprites: Codable, Sendable {
        let frontDefault: String?

        enum CodingKeys: String, CodingKey {
            case frontDefault = "front_default"
        }
    }

    struct PokemonType: Codable, Sendable {
        let type: TypeInfo

        struct TypeInfo: Codable, Sendable {
            let name: String
        }
    }

    struct Stat: Codable, Sendable {
        let baseStat: Int
        let stat: StatInfo

        struct StatInfo: Codable, Sendable {
            let name: String
        }

        enum CodingKeys: String, CodingKey {
            case baseStat = "base_stat"
            case stat
        }
    }
}

struct PokemonList: Codable, Sendable {
    let results: [PokemonListItem]
    let count: Int
    let next: String?
    let previous: String?

    struct PokemonListItem: Codable, Sendable, Identifiable {
        let name: String
        let url: String

        var id: String { name }

        // Extract Pokemon ID from URL
        var pokemonId: Int {
            let components = url.components(separatedBy: "/")
            return Int(components[components.count - 2]) ?? 0
        }
    }
}

// MARK: - Pokemon API Service

enum PokemonAPI {
    static func fetchPokemon(id: Int) async throws -> Pokemon {
        let url = URL(safeString: "https://pokeapi.co/api/v2/pokemon/\(id)")
        print("🔥 API CALL: Fetching Pokemon with ID \(id) from \(url)")
        do {
            try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000)) // Reduced delay for better UX
            let (data, _) = try await URLSession.shared.data(from: url)
            let pokemon = try JSONDecoder().decode(Pokemon.self, from: data)
            print("✅ API SUCCESS: Fetched Pokemon '\(pokemon.name)' (ID: \(id))")
            return pokemon
        } catch {
            print("❌ API ERROR: Failed to fetch Pokemon with ID \(id) - \(error)")
            throw error
        }
    }

    static func fetchPokemonList(limit: Int = 20, offset: Int = 0) async throws -> PokemonList {
        let url = URL(safeString: "https://pokeapi.co/api/v2/pokemon?limit=\(limit)&offset=\(offset)")
        print("🔥 API CALL: Fetching Pokemon list (limit: \(limit), offset: \(offset)) from \(url)")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let pokemonList = try JSONDecoder().decode(PokemonList.self, from: data)
            print("✅ API SUCCESS: Fetched \(pokemonList.results.count) Pokemon in list")
            return pokemonList
        } catch {
            print("❌ API ERROR: Failed to fetch Pokemon list - \(error)")
            throw error
        }
    }

    // MARK: - Infinite Query Support

    /// Fetch Pokemon list page for infinite scrolling
    /// - Parameter pageParam: The offset for pagination (0 for first page, 20 for second, etc.)
    /// - Returns: PokemonList containing results for this page
    static func fetchPokemonPage(offset: Int) async throws -> PokemonList {
        return try await fetchPokemonList(limit: 20, offset: offset)
    }

    static func searchPokemon(name: String) async throws -> Pokemon {
        let url = URL(safeString: "https://pokeapi.co/api/v2/pokemon/\(name.lowercased())")
        print("🔥 API CALL: Searching Pokemon with name '\(name)' from \(url)")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let pokemon = try JSONDecoder().decode(Pokemon.self, from: data)
            print("✅ API SUCCESS: Found Pokemon '\(pokemon.name)' (ID: \(pokemon.id))")
            return pokemon
        } catch {
            print("❌ API ERROR: Failed to search Pokemon with name '\(name)' - \(error)")
            throw error
        }
    }
}

// MARK: - URL Extensions

extension URL {
    /// Use this init for static URL strings to avoid using force unwrap or doing redundant error handling
    /// - Parameter string: static url ie https://www.example.com/privacy/
    init(staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            fatalError("URL is illegal: \(staticString)")
        }
        self = url
    }
}

extension URL {
    init(safeString: String) {
        guard let url = URL(string: safeString) else {
            fatalError("URL is illegal: \(safeString)")
        }
        self = url
    }
}
