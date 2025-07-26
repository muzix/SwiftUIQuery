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

    @Environment(\.queryClient) private var queryClient

    // Timer to refresh UI for real-time stale status updates
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var refreshTrigger = false
    @State private var showingCacheViewer = false
    @State private var navigationPath = NavigationPath()

    // MARK: - Navigation Methods

    private func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }

    private func popToRoot() {
        navigationPath.removeLast(navigationPath.count)
    }

    // MARK: - Computed Properties

    private var statusText: String {
        switch pokemonListQuery.status {
        case .pending: return "Pending"
        case .success: return "Success"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        switch pokemonListQuery.status {
        case .pending: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                if refreshTrigger {
                    EmptyView().hidden()
                } else {
                    EmptyView().hidden()
                }
                // Header
                VStack(spacing: 12) {
                    Text("🔥")
                        .font(.system(size: 50))
                    Text("SwiftUI Query + PokeAPI")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text("✨ TanStack Query v5 API Compatible!")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Pokemon List Section
                        GroupBox("Pokemon List Query Demo") {
                            PokemonListView(listQuery: pokemonListQuery, navigationPath: $navigationPath)
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
                                    Text("Fetch Status:")
                                    Spacer()
                                    Text(pokemonListQuery.fetchStatus.description)
                                        .foregroundColor(.secondary)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("isPending:")
                                    Spacer()
                                    Text(pokemonListQuery.isPending ? "Yes" : "No")
                                        .foregroundColor(pokemonListQuery.isPending ? .blue : .green)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("isLoading:")
                                    Spacer()
                                    Text(pokemonListQuery.isLoading ? "Yes" : "No")
                                        .foregroundColor(pokemonListQuery.isLoading ? .blue : .green)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("isFetching:")
                                    Spacer()
                                    Text(pokemonListQuery.isFetching ? "Yes" : "No")
                                        .foregroundColor(pokemonListQuery.isFetching ? .orange : .green)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("isRefetching:")
                                    Spacer()
                                    Text(pokemonListQuery.isRefetching ? "Yes" : "No")
                                        .foregroundColor(pokemonListQuery.isRefetching ? .orange : .green)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("isFetched:")
                                    Spacer()
                                    Text(pokemonListQuery.isFetched ? "Yes" : "No")
                                        .foregroundColor(pokemonListQuery.isFetched ? .green : .gray)
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

                                HStack(spacing: 12) {
                                    Button("Reset Query") {
                                        _pokemonListQuery.reset()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Invalidate Query") {
                                        _pokemonListQuery.invalidate()
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Divider()

                                Text("Global QueryClient Actions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button("Invalidate All Queries") {
                                    Task {
                                        await queryClient?.invalidateQueries()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pokemon Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !navigationPath.isEmpty {
                        Button {
                            navigationPath.removeLast()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCacheViewer = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("Query Cache Inspector")
                    .help("View all queries in the cache")
                }
            }
            .sheet(isPresented: $showingCacheViewer) {
                QueryCacheViewer()
            }
            .attach(_pokemonListQuery) // Attach lifecycle events to the query
            .onReceive(refreshTimer) { _ in
                // Toggle refresh trigger to force UI update for stale status
                refreshTrigger.toggle()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case let .pokemonDetail(pokemon):
                    PokemonDetailView(pokemon: pokemon)
                default:
                    Text("Demo removed")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
