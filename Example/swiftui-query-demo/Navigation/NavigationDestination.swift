//
//  NavigationDestination.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation

enum NavigationDestination: Hashable {
    case fetcherSearchDemo
    case errorBoundaryDemo
    case multiQueryDemo
    case queryClientDemo
    case pokemonDetail(PokemonList.PokemonListItem)
}
