//
//  PokemonModels.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation

// MARK: - Pokemon List Models

struct PokemonList: Sendable, Codable {
    let results: [PokemonListItem]
    
    struct PokemonListItem: Sendable, Codable, Identifiable, Hashable {
        let name: String
        let url: String
        
        var id: String { name }
        
        var pokemonId: Int {
            let components = url.split(separator: "/")
            return Int(components.last ?? "1") ?? 1
        }
    }
}

// MARK: - Pokemon Detail Model

public struct Pokemon: Sendable, Codable, Identifiable {
    public let id: Int
    public let name: String
    public let height: Int
    public let weight: Int
    public let sprites: Sprites
    public let types: [PokemonType]
    public let stats: [Stat]

    public struct Sprites: Sendable, Codable {
        public let front_default: String?
        public let front_shiny: String?
    }
    
    public struct PokemonType: Sendable, Codable {
        public let type: TypeInfo

        public struct TypeInfo: Sendable, Codable {
            public let name: String
        }
    }
    
    public struct Stat: Sendable, Codable {
        public let base_stat: Int
        public let stat: StatInfo

        public struct StatInfo: Sendable, Codable {
            public let name: String
        }
    }
}
