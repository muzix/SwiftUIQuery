//
//  PokemonColors.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI

// MARK: - Pokemon Type Colors

func typeColor(for type: String) -> Color {
    switch type.lowercased() {
    case "fire": return .red
    case "water": return .blue
    case "grass": return .green
    case "electric": return .yellow
    case "psychic": return .purple
    case "ice": return .cyan
    case "dragon": return .indigo
    case "poison": return .purple
    case "flying": return .mint
    case "fighting": return .orange
    case "ground": return .brown
    case "rock": return .gray
    case "bug": return Color(red: 0.6, green: 0.8, blue: 0.2)
    case "ghost": return .purple
    case "steel": return .gray
    case "fairy": return .pink
    case "dark": return .black
    case "normal": return Color(red: 0.6, green: 0.6, blue: 0.5)
    default: return .gray
    }
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