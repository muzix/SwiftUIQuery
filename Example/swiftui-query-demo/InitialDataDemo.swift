//
//  InitialDataDemo.swift
//  swiftui-query-demo
//
//  Demo showcasing UseQuery with initial data
//

import SwiftUI
import SwiftUIQuery
import Perception

// MARK: - Initial Data Demo View

struct InitialDataDemoView: View {
    @State private var selectedPokemonId = 1
    @State private var showQuickAccess = true
    @State private var showDevTools = false

    // Mock initial data for demonstration
    private let initialPokemonData = Pokemon(
        id: 1,
        name: "bulbasaur",
        height: 7,
        weight: 69,
        sprites: Pokemon
            .Sprites(frontDefault: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/4.png"),
        types: [
            Pokemon.PokemonType(type: Pokemon.PokemonType.TypeInfo(name: "grass")),
            Pokemon.PokemonType(type: Pokemon.PokemonType.TypeInfo(name: "poison"))
        ],
        stats: [
            Pokemon.Stat(baseStat: 45, stat: Pokemon.Stat.StatInfo(name: "hp")),
            Pokemon.Stat(baseStat: 49, stat: Pokemon.Stat.StatInfo(name: "attack")),
            Pokemon.Stat(baseStat: 49, stat: Pokemon.Stat.StatInfo(name: "defense")),
            Pokemon.Stat(baseStat: 65, stat: Pokemon.Stat.StatInfo(name: "special-attack")),
            Pokemon.Stat(baseStat: 65, stat: Pokemon.Stat.StatInfo(name: "special-defense")),
            Pokemon.Stat(baseStat: 45, stat: Pokemon.Stat.StatInfo(name: "speed"))
        ]
    )

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                // Demo Controls
                VStack(alignment: .leading, spacing: 16) {
                    Text("Initial Data Demo")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This demo shows how UseQuery handles initial data to prevent loading states.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pokemon ID:")
                                .fontWeight(.medium)

                            Picker("Pokemon ID", selection: $selectedPokemonId) {
                                Text("1 (Bulbasaur)").tag(1)
                                Text("4 (Charmander)").tag(4)
                                Text("7 (Squirtle)").tag(7)
                                Text("25 (Pikachu)").tag(25)
                                Text("150 (Mewtwo)").tag(150)
                            }
                            .pickerStyle(MenuPickerStyle())
                        }

                        Toggle("Show Quick Access Panel", isOn: $showQuickAccess)
                            .toggleStyle(SwitchToggleStyle())
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))

                Divider()

                // Quick Access Panel (optional)
                if showQuickAccess {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Access")
                            .font(.headline)
                            .fontWeight(.medium)

                        Text("These buttons demonstrate instant data access when initial data is provided.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                QuickAccessButton(
                                    pokemonId: 1,
                                    name: "Bulbasaur",
                                    initialData: initialPokemonData,
                                    selectedId: $selectedPokemonId
                                )
                                QuickAccessButton(
                                    pokemonId: 4,
                                    name: "Charmander",
                                    initialData: nil,
                                    selectedId: $selectedPokemonId
                                )
                                QuickAccessButton(
                                    pokemonId: 7,
                                    name: "Squirtle",
                                    initialData: nil,
                                    selectedId: $selectedPokemonId
                                )
                                QuickAccessButton(
                                    pokemonId: 25,
                                    name: "Pikachu",
                                    initialData: nil,
                                    selectedId: $selectedPokemonId
                                )
                                QuickAccessButton(
                                    pokemonId: 150,
                                    name: "Mewtwo",
                                    initialData: nil,
                                    selectedId: $selectedPokemonId
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))

                    Divider()
                }

                // Main Pokemon Display with Initial Data
                UseQuery(
                    queryKey: "pokemon-initial-\(selectedPokemonId)",
                    queryFn: { _ in try await PokemonAPI.fetchPokemon(id: selectedPokemonId) },
                    staleTime: 30, // 30 seconds for demo - shows stale vs fresh states
                    enabled: true,
                    initialData: selectedPokemonId == 1 ? initialPokemonData : nil
                ) { result in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Status Indicators
                            StatusIndicatorSection(result: result, pokemonId: selectedPokemonId)

                            // Pokemon Content
                            if result.isLoading, result.data == nil {
                                // True loading state (no initial data)
                                LoadingView(message: "Loading Pokemon data...")
                            } else if let error = result.error, result.data == nil {
                                // Error state with no fallback data
                                ErrorView(error: error) {
                                    Task {
                                        _ = try? await result.refetch()
                                    }
                                }
                            } else if let pokemon = result.data {
                                // Success state (with data - could be initial, cached, or fresh)
                                VStack(spacing: 16) {
                                    // Data source indicator
                                    DataSourceIndicator(
                                        result: result,
                                        pokemon: pokemon,
                                        initialData: selectedPokemonId == 1 ? initialPokemonData : nil
                                    )

                                    // Pokemon details
                                    PokemonDetailContent(pokemon: pokemon)

                                    // Background refetch indicator
                                    if result.isFetching, result.data != nil {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Refreshing data in background...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            } else {
                                // No data state
                                VStack(spacing: 16) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)

                                    Text("No Pokemon Data")
                                        .font(.title2)
                                        .fontWeight(.medium)

                                    Text("No data available for Pokemon #\(selectedPokemonId)")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Initial Data Demo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("🛠️") {
                    showDevTools = true
                }
            }
        }
        .sheet(isPresented: $showDevTools) {
            DevToolsView()
        }
    }
}

// MARK: - Quick Access Button

struct QuickAccessButton: View {
    let pokemonId: Int
    let name: String
    let initialData: Pokemon?
    @Binding var selectedId: Int

    var body: some View {
        Button(action: {
            selectedId = pokemonId
        }) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("#\(pokemonId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Indicator for initial data availability
                Circle()
                    .fill(initialData != nil ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedId == pokemonId ? Color.blue.opacity(0.2) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedId == pokemonId ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Status Indicator Section

struct StatusIndicatorSection: View {
    let result: UseQueryResult<Pokemon>
    let pokemonId: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query Status")
                .font(.headline)
                .fontWeight(.medium)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                StatusBadge(label: "Loading", isActive: result.isLoading, color: .blue)
                StatusBadge(label: "Fetching", isActive: result.isFetching, color: .orange)
                StatusBadge(label: "Success", isActive: result.isSuccess, color: .green)
                StatusBadge(label: "Error", isActive: result.isError, color: .red)
                StatusBadge(label: "Stale", isActive: result.isStale, color: .yellow)
                StatusBadge(label: "Refetching", isActive: result.isRefetching, color: .purple)
            }

            // Additional status info
            VStack(alignment: .leading, spacing: 6) {
                if let dataUpdatedAt = result.dataUpdatedAt {
                    HStack {
                        Text("Data Updated:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatLastUpdated(dataUpdatedAt))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text("Data Update Count:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(result.dataUpdateCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                if result.failureCount > 0 {
                    HStack {
                        Text("Failure Count:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(result.failureCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let label: String
    let isActive: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .medium : .regular)
                .foregroundColor(isActive ? color : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? color.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Data Source Indicator

struct DataSourceIndicator: View {
    let result: UseQueryResult<Pokemon>
    let pokemon: Pokemon
    let initialData: Pokemon?

    private var dataSource: (label: String, color: Color, description: String) {
        if let initialData, pokemon.id == initialData.id, result.dataUpdateCount == 0 {
            return ("Initial Data", .blue, "Showing provided initial data")
        } else if result.dataUpdateCount == 0 {
            return ("Cached Data", .green, "Data loaded from cache")
        } else if result.isStale {
            return ("Stale Data", .orange, "Data is outdated but being refreshed")
        } else {
            return ("Fresh Data", .green, "Data is up-to-date from server")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(dataSource.color)
                        .frame(width: 10, height: 10)

                    Text(dataSource.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(dataSource.color)
                }

                Text(dataSource.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Manual refresh button
            Button("Refresh") {
                Task { [result] in
                    _ = try? await result.refetch()
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .disabled(result.isFetching)
        }
        .padding()
        .background(dataSource.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Previews

#Preview("Initial Data Demo") {
    NavigationView {
        InitialDataDemoView()
            .queryClient()
    }
}

#Preview("Quick Access Button") {
    HStack {
        QuickAccessButton(pokemonId: 1, name: "Bulbasaur", initialData: Pokemon(
            id: 1, name: "bulbasaur", height: 7, weight: 69,
            sprites: Pokemon.Sprites(frontDefault: nil),
            types: [], stats: []
        ), selectedId: .constant(1))

        QuickAccessButton(pokemonId: 4, name: "Charmander", initialData: nil, selectedId: .constant(1))
    }
    .padding()
}
