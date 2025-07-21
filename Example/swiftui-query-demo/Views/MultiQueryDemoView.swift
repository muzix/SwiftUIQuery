//
//  MultiQueryDemoView.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

struct MultiQueryDemoView: View {
    @Environment(\.queryClient) private var queryClient
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                queryComponentsSection
                globalActionsSection
            }
            .padding()
        }
        .navigationTitle("Multi-Query Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            Text("Multiple Queries in One View")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Each component below has its own query. Use QueryClient to invalidate them all at once!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Query Components
    
    private var queryComponentsSection: some View {
        VStack(spacing: 16) {
            Text("Individual Query Components")
                .font(.headline)
            
            // Each component has its own query
            PokemonCardComponent(pokemonId: 1, name: "Bulbasaur")
            PokemonCardComponent(pokemonId: 4, name: "Charmander")
            PokemonCardComponent(pokemonId: 7, name: "Squirtle")
            PokemonCardComponent(pokemonId: 25, name: "Pikachu")
        }
    }
    
    // MARK: - Global Actions
    
    private var globalActionsSection: some View {
        GroupBox("QueryClient Global Actions") {
            VStack(spacing: 12) {
                Text("Affect all Pokemon queries above simultaneously")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 8) {
                    Button("🔄 Invalidate All Pokemon Queries") {
                        Task {
                            await queryClient?.invalidateQueries(
                                filter: .predicate { key in
                                    key.stringValue.hasPrefix("pokemon-")
                                }
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("⚡ Refetch All Pokemon Queries") {
                        Task {
                            await queryClient?.refetchQueries(
                                filter: .predicate { key in
                                    key.stringValue.hasPrefix("pokemon-")
                                }
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("🧹 Clear All Queries") {
                        queryClient?.clear()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                    Divider()
                    
                    Text("Target Specific States")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button("Active Only") {
                            Task {
                                await queryClient?.invalidateQueries(
                                    filter: .predicate { key in
                                        key.stringValue.hasPrefix("pokemon-")
                                    },
                                    refetchType: .active
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button("Inactive Only") {
                            Task {
                                await queryClient?.invalidateQueries(
                                    filter: .predicate { key in
                                        key.stringValue.hasPrefix("pokemon-")
                                    },
                                    refetchType: .inactive
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button("No Refetch") {
                            Task {
                                await queryClient?.invalidateQueries(
                                    filter: .predicate { key in
                                        key.stringValue.hasPrefix("pokemon-")
                                    },
                                    refetchType: .none
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Pokemon Card Component

struct PokemonCardComponent: View {
    let pokemonId: Int
    let name: String
    
    @Query<Fetcher<Pokemon>> var pokemonQuery: QueryState<Pokemon>
    @State private var refreshTrigger = false
    
    init(pokemonId: Int, name: String) {
        self.pokemonId = pokemonId
        self.name = name
        
        self._pokemonQuery = Query(
            "pokemon-\(pokemonId)",
            fetch: { try await fetchPokemon(id: pokemonId) },
            options: QueryOptions(
                staleTime: .seconds(15),
                refetchOnAppear: .ifStale
            )
        )
    }
    
    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                headerRow
                
                if pokemonQuery.isLoading && pokemonQuery.data == nil {
                    loadingView
                } else if let pokemon = pokemonQuery.data {
                    pokemonContentView(pokemon)
                } else if let error = pokemonQuery.error {
                    errorView(error)
                } else {
                    idleView
                }
                
                actionButtons
            }
        } label: {
            HStack {
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                statusBadge
                staleBadge
            }
        }
        .attach(_pokemonQuery)
    }
    
    private var headerRow: some View {
        HStack {
            Text("Query Key: pokemon-\(pokemonId)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if pokemonQuery.isFetching {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
    
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var staleBadge: some View {
        Group {
            if refreshTrigger {
                EmptyView().hidden()
            } else {
                EmptyView().hidden()
            }
            
            Text(pokemonQuery.isStale ? "STALE" : "FRESH")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((pokemonQuery.isStale ? Color.orange : Color.green).opacity(0.2))
                .foregroundColor(pokemonQuery.isStale ? .orange : .green)
                .cornerRadius(4)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            refreshTrigger.toggle()
        }
    }
    
    private var statusText: String {
        switch pokemonQuery.status {
        case .idle: return "IDLE"
        case .loading: return "LOADING"
        case .success: return "SUCCESS"
        case .error: return "ERROR"
        }
    }
    
    private var statusColor: Color {
        switch pokemonQuery.status {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading \(name)...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var idleView: some View {
        Text("Query not yet executed")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
    }
    
    private func pokemonContentView(_ pokemon: Pokemon) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: pokemon.sprites.front_default ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .scaleEffect(0.5)
            }
            .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pokemon.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("№\(String(format: "%03d", pokemon.id))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    ForEach(pokemon.types.prefix(2), id: \.type.name) { type in
                        Text(type.type.name.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(pokemonTypeColor(for: type.type.name).opacity(0.3))
                            .foregroundColor(pokemonTypeColor(for: type.type.name))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Double(pokemon.height) / 10.0, specifier: "%.1f")m")
                    .font(.caption2)
                Text("\(Double(pokemon.weight) / 10.0, specifier: "%.1f")kg")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Failed to load")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Refetch") {
                _pokemonQuery.refetch()
            }
            .buttonStyle(.bordered)
            .font(.caption)
            
            Button("Reset") {
                _pokemonQuery.reset()
            }
            .buttonStyle(.bordered)
            .font(.caption)
            
            Button("Invalidate") {
                _pokemonQuery.invalidate()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
}

// MARK: - Helper Functions

private func pokemonTypeColor(for typeName: String) -> Color {
    switch typeName.lowercased() {
    case "fire": return .red
    case "water": return .blue
    case "grass": return .green
    case "electric": return .yellow
    case "psychic": return .purple
    case "ice": return .cyan
    case "dragon": return .indigo
    case "dark": return .black
    case "fairy": return .pink
    case "fighting": return .red
    case "poison": return .purple
    case "ground": return .brown
    case "flying": return .mint
    case "bug": return .green
    case "rock": return .brown
    case "ghost": return .purple
    case "steel": return .gray
    case "normal": return .gray
    default: return .gray
    }
}

#Preview {
    let queryClient = QueryClient()
    
    return NavigationStack {
        MultiQueryDemoView()
    }
    .queryClient(queryClient)
}
