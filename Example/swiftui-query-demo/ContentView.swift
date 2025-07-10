//
//  ContentView.swift
//  swiftui-query-demo
//
//  Created by Hoang Pham on 9/7/25.
//

import SwiftUI
import SwiftUIQuery

// MARK: - Main Demo View

struct ContentView: View {
    
    // Query for Pokemon list
    @Query("pokemon-list", fetch: fetchPokemonList, options: QueryOptions(staleTime: .seconds(30)))
    var pokemonListQuery
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("🔥")
                        .font(.system(size: 50))
                    Text("SwiftUI Query + PokeAPI")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Pokemon List Section
                        GroupBox("Pokemon List Query Demo") {
                            PokemonListView(listQuery: pokemonListQuery)
                        }
                        
                        // Actions Section
                        GroupBox("Query Actions") {
                            VStack(spacing: 12) {
                                Button("Refresh Pokemon List") {
                                    _pokemonListQuery.refetch()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Reset Query") {
                                    _pokemonListQuery.reset()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Invalidate Query") {
                                    _pokemonListQuery.invalidate()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pokemon Demo")
            .navigationBarTitleDisplayMode(.inline)
            .attach(_pokemonListQuery)  // Attach lifecycle events to the query
        }
    }
}

#Preview {
    ContentView()
}
