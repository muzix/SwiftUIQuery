//
//  PokemonAPI.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation

// MARK: - Pokemon API Functions

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

@Sendable
func fetchPokemonList() async throws -> PokemonList {
    print("fetchPokemonList - starting with 2 second delay")

    // Add artificial delay to showcase loading state
    try await Task.sleep(for: .seconds(2))

    let url = URL(staticString: "https://pokeapi.co/api/v2/pokemon?limit=20")
    let (data, _) = try await URLSession.shared.data(from: url)
    let result = try JSONDecoder().decode(PokemonList.self, from: data)

    print("fetchPokemonList - completed")
    return result
}

@Sendable
func fetchPokemon(id: Int) async throws -> Pokemon {
    print("fetchPokemon(\(id)) - starting with 1 second delay")

    // Add artificial delay to showcase loading state
    try await Task.sleep(for: .seconds(1))

    let url = URL(safeString: "https://pokeapi.co/api/v2/pokemon/\(id)")
    let (data, _) = try await URLSession.shared.data(from: url)
    let result = try JSONDecoder().decode(Pokemon.self, from: data)

    print("fetchPokemon(\(id)) - completed")
    return result
}
