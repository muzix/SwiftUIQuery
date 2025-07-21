//
//  FetcherSearchDemoView.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

struct FetcherSearchDemoView: View {
    @State private var searchText = ""
    @State private var searchHistory: [String] = []
    @Environment(\.queryClient) private var queryClient
    @State private var showingCacheViewer = false
    
    // Create fetcher instance that will hold dynamic search term
    @StateObject private var pokemonFetcher = PokemonSearchFetcher()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                searchSection
                
                if !searchText.isEmpty {
                    searchResultsSection
                } else {
                    searchHistorySection
                }
                
                queryManagementSection
            }
            .padding()
        }
        .navigationTitle("FetchProtocol Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCacheViewer = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
                .accessibilityLabel("Query Cache Inspector")
            }
        }
        .sheet(isPresented: $showingCacheViewer) {
            QueryCacheViewer()
        }
        .onChange(of: searchText) { _, newValue in
            // Update the fetcher's search term (dynamic!)
            pokemonFetcher.searchTerm = newValue
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            Text("FetchProtocol Dynamic Search")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("✨ Uses FetchProtocol objects with dynamic properties!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                Text("The fetcher object accesses current searchTerm each time fetch() is called")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            TextField("Search Pokemon (e.g., pikachu, charizard, bulbasaur)", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current fetcher.searchTerm: '\(pokemonFetcher.searchTerm)'")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .fontWeight(.medium)
                        
                        Text("Query will use this dynamic value when executed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Clear") {
                        searchText = ""
                        pokemonFetcher.searchTerm = ""
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsSection: some View {
        VStack(spacing: 16) {
            Text("Live Search with FetchProtocol")
                .font(.headline)
            
            FetcherSearchResultView(fetcher: pokemonFetcher) { searchTerm in
                // Add to history when search completes successfully
                if !searchHistory.contains(searchTerm.lowercased()) {
                    searchHistory.append(searchTerm.lowercased())
                }
            }
        }
    }
    
    // MARK: - Search History
    
    private var searchHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Search History")
                    .font(.headline)
                
                Spacer()
                
                if !searchHistory.isEmpty {
                    Button("Clear History") {
                        searchHistory.removeAll()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            
            if searchHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No previous searches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Try searching for: pikachu, charizard, mew, or rayquaza")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120), spacing: 12)
                ], spacing: 12) {
                    ForEach(searchHistory.reversed(), id: \.self) { term in
                        FetcherHistoryCard(searchTerm: term) {
                            // When tapped, set as current search
                            searchText = term
                            pokemonFetcher.searchTerm = term
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Query Management
    
    private var queryManagementSection: some View {
        GroupBox("FetchProtocol Query Management") {
            VStack(spacing: 12) {
                Text("Each search creates a query with the fetcher object. The fetcher can access dynamic properties!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 8) {
                    Button("Invalidate All Fetcher Queries") {
                        Task {
                            await queryClient?.invalidateQueries(
                                filter: .predicate { key in
                                    key.stringValue.hasPrefix("fetcher-search-")
                                }
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Clear All Fetcher Queries") {
                        queryClient?.removeQueries(
                            filter: .predicate { key in
                                key.stringValue.hasPrefix("fetcher-search-")
                            }
                        )
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Fetcher Search Result View

struct FetcherSearchResultView: View {
    let fetcher: PokemonSearchFetcher
    let onSuccessfulSearch: (String) -> Void
    
    @Query<PokemonSearchFetcher> var searchQuery: QueryState<Pokemon>

    init(fetcher: PokemonSearchFetcher, onSuccessfulSearch: @escaping (String) -> Void) {
        self.fetcher = fetcher
        self.onSuccessfulSearch = onSuccessfulSearch
        
        // Use the new fetcher-based initializer!
        self._searchQuery = Query(
            "fetcher-search-pokemon", // Single key since fetcher handles dynamic input
            fetcher: fetcher,
            options: QueryOptions(
                staleTime: .seconds(30),
                refetchOnAppear: .ifStale
            )
        )
    }
    
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                queryInfoView
                contentView
                actionButtons
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Query: fetcher-search-pokemon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Fetcher.searchTerm: '\(fetcher.searchTerm)'")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                statusBadge
            }
        }
        .attach(_searchQuery)
    }
    
    private var queryInfoView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🎯 FetchProtocol Magic:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("• Query key stays the same")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• Fetcher accesses current searchTerm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• No closure capture limitations!")
                    .font(.caption2)
                    .foregroundColor(.purple)
                    .fontWeight(.medium)
                
                if let lastUpdated = searchQuery.dataUpdatedAt {
                    Text("Last fetched: \(lastUpdated, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if searchQuery.isFetching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if searchQuery.isLoading && searchQuery.data == nil {
            loadingView
        } else if let pokemon = searchQuery.data {
            pokemonResultView(pokemon)
        } else if let error = searchQuery.error {
            errorView(error)
        } else {
            idleView
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
    
    private var statusText: String {
        switch searchQuery.status {
        case .idle: return "IDLE"
        case .loading: return "SEARCHING"
        case .success: return "FOUND"
        case .error: return "ERROR"
        }
    }
    
    private var statusColor: Color {
        switch searchQuery.status {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Searching for '\(fetcher.searchTerm)'...")
                .font(.subheadline)
        }
        .padding(.vertical, 20)
    }
    
    private var idleView: some View {
        Text("Enter a Pokemon name to search")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 20)
    }
    
    private func pokemonResultView(_ pokemon: Pokemon) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: pokemon.sprites.front_default ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(pokemon.name.capitalized)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("National №\(String(format: "%03d", pokemon.id))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(pokemon.types.prefix(3), id: \.type.name) { type in
                            Text(type.type.name.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(pokemonTypeColor(for: type.type.name).opacity(0.3))
                                .foregroundColor(pokemonTypeColor(for: type.type.name))
                                .cornerRadius(6)
                        }
                    }
                }
                
                Spacer()
            }
            
            Text("✨ Fetched using FetchProtocol with dynamic searchTerm!")
                .font(.caption)
                .foregroundColor(.purple)
                .fontWeight(.medium)
                .onAppear {
                    onSuccessfulSearch(fetcher.searchTerm)
                }
        }
        .padding(.vertical, 8)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Search failed")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button("Refetch Current Term") {
                    _searchQuery.refetch()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
                
                Button("Reset") {
                    _searchQuery.reset()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            
            Text("✨ NEW API Demo:")
                .font(.caption2)
                .foregroundColor(.purple)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                Button("Search 'pikachu'") {
                    _searchQuery.refetch { $0.searchTerm = "pikachu" }
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Button("Search 'charizard'") {
                    _searchQuery.refetch { $0.searchTerm = "charizard" }
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Button("Search 'mew'") {
                    _searchQuery.refetch { $0.searchTerm = "mew" }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }
}

// MARK: - Fetcher History Card

struct FetcherHistoryCard: View {
    let searchTerm: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                
                Text(searchTerm.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("TAP TO SEARCH")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
        FetcherSearchDemoView()
    }
    .queryClient(queryClient)
}
