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

struct Pokemon: Sendable, Codable, Identifiable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let sprites: Sprites
    let types: [PokemonType]
    let stats: [Stat]
    
    struct Sprites: Sendable, Codable {
        let front_default: String?
        let front_shiny: String?
    }
    
    struct PokemonType: Sendable, Codable {
        let type: TypeInfo
        
        struct TypeInfo: Sendable, Codable {
            let name: String
        }
    }
    
    struct Stat: Sendable, Codable {
        let base_stat: Int
        let stat: StatInfo
        
        struct StatInfo: Sendable, Codable {
            let name: String
        }
    }
}