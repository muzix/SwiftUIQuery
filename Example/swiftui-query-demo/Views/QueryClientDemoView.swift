//
//  QueryClientDemoView.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

struct QueryClientDemoView: View {
    @Environment(\.queryClient) private var queryClient
    @State private var refreshTrigger = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    activeInactiveDemoSection
                    globalActionsSection
                }
                .padding()
            }
            .navigationTitle("QueryClient Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Active/Inactive Query Tracking")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Navigate between views to see how queries become active/inactive")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Active/Inactive Demo
    
    private var activeInactiveDemoSection: some View {
        GroupBox("Query Views") {
            VStack(spacing: 16) {
                Text("Each view below has its own Pokemon query. When you navigate to a view, its query becomes 'active'. When you leave, it becomes 'inactive'.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    NavigationLink("View 1: Pikachu Query") {
                        PokemonQueryView(pokemonId: 25, name: "Pikachu", viewNumber: 1)
                    }
                    .buttonStyle(.bordered)
                    
                    NavigationLink("View 2: Charizard Query") {
                        PokemonQueryView(pokemonId: 6, name: "Charizard", viewNumber: 2)
                    }
                    .buttonStyle(.bordered)
                    
                    NavigationLink("View 3: Blastoise Query") {
                        PokemonQueryView(pokemonId: 9, name: "Blastoise", viewNumber: 3)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Global Actions
    
    private var globalActionsSection: some View {
        GroupBox("QueryClient Global Actions") {
            VStack(spacing: 12) {
                Text("These actions affect ALL queries managed by the QueryClient")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Button("Invalidate All Queries") {
                        Task {
                            await queryClient?.invalidateQueries()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Invalidate Active Queries Only") {
                        Task {
                            await queryClient?.invalidateQueries(refetchType: .active)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Invalidate Inactive Queries Only") {
                        Task {
                            await queryClient?.invalidateQueries(refetchType: .inactive)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Refetch All Pokemon Queries") {
                        Task {
                            await queryClient?.refetchQueries(
                                filter: .predicate { key in
                                    key.stringValue.contains("pokemon-")
                                }
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear All Queries") {
                        queryClient?.clear()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Individual Pokemon Query View

struct PokemonQueryView: View {
    let pokemonId: Int
    let name: String
    let viewNumber: Int
    
    @Query<Fetcher<Pokemon>> var pokemonQuery: QueryState<Pokemon>
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var refreshTrigger = false
    
    init(pokemonId: Int, name: String, viewNumber: Int) {
        self.pokemonId = pokemonId
        self.name = name
        self.viewNumber = viewNumber
        
        self._pokemonQuery = Query(
            "pokemon-\(pokemonId)",
            fetch: { try await fetchPokemon(id: pokemonId) },
            options: QueryOptions(
                staleTime: .seconds(10),
                refetchOnAppear: .ifStale
            )
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                queryStatusSection
                contentSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle("\(name) Query")
        .navigationBarTitleDisplayMode(.inline)
        .attach(_pokemonQuery)
        .onReceive(refreshTimer) { _ in
            refreshTrigger.toggle()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🎯 View \(viewNumber)")
                .font(.title)
            
            Text("This query is now ACTIVE")
                .font(.headline)
                .foregroundColor(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            
            Text("When you navigate back, it becomes INACTIVE")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var queryStatusSection: some View {
        GroupBox("Query Status") {
            VStack(spacing: 8) {
                if refreshTrigger {
                    EmptyView().hidden()
                } else {
                    EmptyView().hidden()
                }
                
                HStack {
                    Text("Status:")
                    Spacer()
                    statusBadge
                }
                
                HStack {
                    Text("Data is stale:")
                    Spacer()
                    Text(pokemonQuery.isStale ? "Yes" : "No")
                        .foregroundColor(pokemonQuery.isStale ? .orange : .green)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Is Loading:")
                    Spacer()
                    Text(pokemonQuery.isFetching ? "Yes" : "No")
                        .foregroundColor(pokemonQuery.isFetching ? .blue : .gray)
                        .fontWeight(.medium)
                }
                
                if let lastUpdated = pokemonQuery.dataUpdatedAt {
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
    }
    
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusText: String {
        switch pokemonQuery.status {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .success: return "Success"
        case .error: return "Error"
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
    private var contentSection: some View {
        if pokemonQuery.isLoading {
            ProgressView("Loading \(name)...")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let pokemon = pokemonQuery.data {
            pokemonContentView(pokemon)
        } else if let error = pokemonQuery.error {
            errorView(error)
        }
    }
    
    private func pokemonContentView(_ pokemon: Pokemon) -> some View {
        GroupBox("\(pokemon.name.capitalized) Details") {
            VStack(spacing: 16) {
                AsyncImage(url: URL(string: pokemon.sprites.front_default ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 120, height: 120)
                
                VStack(spacing: 8) {
                    Text("National №\(String(format: "%03d", pokemon.id))")
                        .font(.headline)
                    
                    HStack {
                        Text("Height: \(Double(pokemon.height) / 10.0, specifier: "%.1f") m")
                        Spacer()
                        Text("Weight: \(Double(pokemon.weight) / 10.0, specifier: "%.1f") kg")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(pokemon.types, id: \.type.name) { type in
                            Text(type.type.name.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        GroupBox("Error") {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                
                Text("Failed to load \(name)")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var actionsSection: some View {
        GroupBox("Query Actions") {
            VStack(spacing: 8) {
                Button("Refetch \(name)") {
                    _pokemonQuery.refetch()
                }
                .buttonStyle(.borderedProminent)
                
                HStack(spacing: 12) {
                    Button("Reset") {
                        _pokemonQuery.reset()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Invalidate") {
                        _pokemonQuery.invalidate()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

#Preview("QueryClient Demo") {
    let queryClient = QueryClient()
    
    return QueryClientDemoView()
        .queryClient(queryClient)
}

#Preview("Pokemon Query View") {
    let queryClient = QueryClient()
    
    return NavigationStack {
        PokemonQueryView(pokemonId: 25, name: "Pikachu", viewNumber: 1)
    }
    .queryClient(queryClient)
}
