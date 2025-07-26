//
//  PokemonColors.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI

// MARK: - Pokemon Type Colors

func typeColor(for type: String) -> Color {
    let typeColors: [String: Color] = [
        "fire": .red,
        "water": .blue,
        "grass": .green,
        "electric": .yellow,
        "psychic": .purple,
        "ice": .cyan,
        "dragon": .indigo,
        "poison": .purple,
        "flying": .mint,
        "fighting": .orange,
        "ground": .brown,
        "rock": .gray,
        "bug": Color(red: 0.6, green: 0.8, blue: 0.2),
        "ghost": .purple,
        "steel": .gray,
        "fairy": .pink,
        "dark": .black,
        "normal": Color(red: 0.6, green: 0.6, blue: 0.5)
    ]

    return typeColors[type.lowercased()] ?? .gray
}

// MARK: - Pokemon Stat Colors

func statColor(for stat: String) -> Color {
    switch stat.lowercased() {
    case "hp": return .red
    case "attack": return .orange
    case "defense": return .blue
    case "special-attack": return .purple
    case "special-defense": return .green
    case "speed": return .pink
    default: return .gray
    }
}

// MARK: - Stat Name Formatting

func formatStatName(_ name: String) -> String {
    switch name.lowercased() {
    case "hp": return "HP"
    case "attack": return "Attack"
    case "defense": return "Defense"
    case "special-attack": return "Sp. Attack"
    case "special-defense": return "Sp. Defense"
    case "speed": return "Speed"
    default: return name.capitalized
    }
}
