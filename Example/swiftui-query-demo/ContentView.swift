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
    @Query("pokemon-list", fetch: fetchPokemonList, options: QueryOptions(staleTime: .seconds(5)))
    var pokemonListQuery
    
    // Timer to refresh UI for real-time stale status updates
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var refreshTrigger = false
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch pokemonListQuery.status {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .success: return "Success"
        case .error: return "Error"
        }
    }
    
    private var statusColor: Color {
        switch pokemonListQuery.status {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if refreshTrigger {
                    EmptyView().hidden()
                } else {
                    EmptyView().hidden()
                }
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
                        
                        // Query Status Section
                        GroupBox("Query Status") {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Status:")
                                    Spacer()
                                    Text(statusText)
                                        .foregroundColor(statusColor)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Data is stale:")
                                    Spacer()
                                    Text(pokemonListQuery.isStale ? "Yes" : "No")
                                        .foregroundColor(pokemonListQuery.isStale ? .orange : .green)
                                        .fontWeight(.medium)
                                }
                                
                                if let lastUpdated = pokemonListQuery.dataUpdatedAt {
                                    HStack {
                                        Text("Last updated:")
                                        Spacer()
                                        Text(lastUpdated, style: .relative)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                }
                            }
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
            .onReceive(refreshTimer) { _ in
                // Toggle refresh trigger to force UI update for stale status
                refreshTrigger.toggle()
            }
        }
    }
}

#Preview {
    ContentView()
}
