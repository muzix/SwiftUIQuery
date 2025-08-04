//
//  ContentView.swift
//  swiftui-query-demo
//
//  Created by Hoang Pham on 9/7/25.
//

import SwiftUI
import SwiftUIQuery
import Perception

// MARK: - Main Demo View

struct ContentView: View {
    @State private var showDevTools = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("🔍")
                        .font(.system(size: 60))

                    Text("SwiftUI Query Demo")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Explore different query patterns and features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    NavigationLink(destination: PokemonListView()) {
                        DemoButton(
                            icon: "list.bullet.rectangle",
                            title: "Pokemon List",
                            description: "Infinite scrolling Pokemon list with automatic pagination"
                        )
                    }

                    NavigationLink(destination: PokemonSearchView()) {
                        DemoButton(
                            icon: "magnifyingglass",
                            title: "Search Pokemon",
                            description: "Real-time search with throttling and error handling"
                        )
                    }

                    NavigationLink(destination: InitialDataDemoView()) {
                        DemoButton(
                            icon: "clock.arrow.circlepath",
                            title: "Initial Data",
                            description: "Queries with pre-populated cache data"
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("SwiftUI Query")
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
}

struct DemoButton: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Pokemon List View

struct PokemonListView: View {
    @State private var showDevTools = false

    var body: some View {
        WithPerceptionTracking {
            UseInfiniteQuery(
                queryKey: "pokemon-infinite-list",
                queryFn: { _, pageParam in
                    try await PokemonAPI.fetchPokemonPage(offset: pageParam ?? 0)
                },
                getNextPageParam: { pages in
                    // Calculate next offset based on current pages
                    let currentTotal = pages.reduce(0) { total, page in total + page.results.count }
                    let lastPage = pages.last

                    // If we have next URL or haven't reached the total count, continue pagination
                    if let lastPage, lastPage.next != nil {
                        return currentTotal
                    }
                    return nil // No more pages
                },
                initialPageParam: 0,
                staleTime: 5 * 60 // 5 minutes before considered stale
            ) { result in
                if result.isLoading, result.data?.pages.isEmpty != false {
                    // Initial loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Pokemon...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = result.error, result.data?.pages.isEmpty != false {
                    // Error state when no data is loaded
                    ErrorView(error: error) {
                        Task {
                            _ = try? await result.refetch()
                        }
                    }
                } else if let infiniteData = result.data {
                    // Show the list with infinite scrolling
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Render all Pokemon from all pages
                            ForEach(infiniteData.pages.indices, id: \.self) { pageIndex in
                                let page = infiniteData.pages[pageIndex]
                                ForEach(page.results) { pokemon in
                                    NavigationLink(destination: PokemonDetailView(pokemonId: pokemon.pokemonId)) {
                                        PokemonListRow(pokemon: pokemon)
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    // Add divider except for last item
                                    if pokemon.id != page.results.last?.id || pageIndex != infiniteData.pages
                                        .count - 1 {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }

                            // Load more section
                            if result.hasNextPage {
                                VStack(spacing: 12) {
                                    if result.isFetchingNextPage {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading more Pokemon...")
                                                .foregroundColor(.secondary)
                                                .font(.subheadline)
                                        }
                                        .padding()
                                    } else {
                                        Button("Load More Pokemon") {
                                            Task {
                                                _ = await result.fetchNextPage()
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .padding()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .onAppear {
                                    // Auto-load when this view appears (infinite scrolling)
                                    if !result.isFetchingNextPage {
                                        Task {
                                            _ = await result.fetchNextPage()
                                        }
                                    }
                                }
                            } else {
                                // End of list indicator
                                VStack(spacing: 8) {
                                    Text("🎉")
                                        .font(.title)
                                    Text("You've seen all available Pokemon!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .refreshable {
                        _ = try? await result.refetch()
                    }
                } else {
                    Text("No Pokemon found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Pokemon")
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
}

// MARK: - Pokemon List Row

struct PokemonListRow: View {
    let pokemon: PokemonList.PokemonListItem

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 12) {
                // Pokemon sprite using nested UseQuery
                UseQuery(
                    queryKey: "pokemon-sprite-\(pokemon.pokemonId)",
                    queryFn: { _ in try await PokemonAPI.fetchPokemon(id: pokemon.pokemonId) },
                    staleTime: 15 * 60 // Sprites cached longer
                ) { spriteResult in
                    Group {
                        if let pokemon = spriteResult.data,
                           let spriteURL = pokemon.sprites.frontDefault,
                           let url = URL(string: spriteURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text("?")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(pokemon.name.capitalized)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("#\(pokemon.pokemonId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Pokemon Detail View

struct PokemonDetailView: View {
    let pokemonId: Int
    @State private var showDevTools = false

    var body: some View {
        WithPerceptionTracking {
            UseQuery(
                queryKey: "pokemon-\(pokemonId)",
                queryFn: { _ in try await PokemonAPI.fetchPokemon(id: pokemonId) },
                staleTime: 10 * 60 // 10 minutes,
            ) { result in
                ScrollView {
                    if result.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading Pokemon details...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                        .padding()
                    } else if let error = result.error {
                        ErrorView(error: error) {
                            Task {
                                _ = try? await result.refetch()
                            }
                        }
                    } else if let pokemon = result.data {
                        PokemonDetailContent(pokemon: pokemon)
                    } else {
                        Text("Pokemon not found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 400)
                    }
                }
                .navigationTitle(result.data?.name.capitalized ?? "Pokemon")
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    _ = try? await result.refetch()
                }
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
    }
}

// MARK: - Pokemon Detail Content

struct PokemonDetailContent: View {
    let pokemon: Pokemon

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Pokemon Image
            if let spriteURL = pokemon.sprites.frontDefault,
               let url = URL(string: spriteURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 200, height: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .frame(maxWidth: .infinity)
            }

            // Basic Information
            VStack(alignment: .leading, spacing: 16) {
                Text("Basic Information")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    InfoRow(label: "ID", value: "#\(pokemon.id)")
                    InfoRow(label: "Height", value: String(format: "%.1f m", Double(pokemon.height) / 10))
                    InfoRow(label: "Weight", value: String(format: "%.1f kg", Double(pokemon.weight) / 10))
                }

                // Types
                VStack(alignment: .leading, spacing: 8) {
                    Text("Types")
                        .font(.headline)

                    HStack {
                        ForEach(pokemon.types, id: \.type.name) { type in
                            Text(type.type.name.capitalized)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(typeColor(for: type.type.name))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(16)

            // Stats
            VStack(alignment: .leading, spacing: 16) {
                Text("Base Stats")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    ForEach(pokemon.stats, id: \.stat.name) { stat in
                        StatBar(name: stat.stat.name, value: stat.baseStat)
                    }
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(16)
        }
        .padding()
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text("\(label):")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Stat Bar Component

struct StatBar: View {
    let name: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatStatName(name))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(statColor(for: name))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(statColor(for: name))
                        .frame(width: geometry.size.width * CGFloat(min(value, 255)) / 255, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Pokemon Search View

struct PokemonSearchView: View {
    @State private var searchText = ""
    @State private var searchKey = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showDevTools = false

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                // Search Bar
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search Pokemon name or ID...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            throttledSearch(newValue)
                        }

                    Text("Search automatically as you type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding()

                // Search Results
                if !searchKey.isEmpty {
                    UseQuery(
                        queryKey: "pokemon-search-\(searchKey)",
                        queryFn: { _ in try await PokemonAPI.searchPokemon(name: searchKey) },
                        staleTime: 5, // 5 seconds for demo purposes - easier to see stale status
                        enabled: !searchKey.isEmpty
                    ) { result in
                        if result.isLoading, result.error == nil {
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("Searching for \(searchKey)...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let queryError = result.error {
                            if !queryError.isNetworkError {
                                // Pokemon not found (API error)
                                VStack(spacing: 20) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.orange)

                                    Text("Pokemon Not Found")
                                        .font(.title2)
                                        .fontWeight(.medium)

                                    Text("No Pokemon named '\(searchKey)' exists. Try a different name or ID.")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                            } else {
                                // Network connection error
                                VStack(spacing: 20) {
                                    Image(systemName: "wifi.exclamationmark")
                                        .font(.system(size: 50))
                                        .foregroundColor(.red)

                                    Text("Connection Error")
                                        .font(.title2)
                                        .fontWeight(.medium)

                                    Text(
                                        "Unable to search for Pokemon. " +
                                            "Please check your internet connection and try again."
                                    )
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                    Button("Try Again") {
                                        Task {
                                            _ = try? await result.refetch()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                            }
                        } else if let pokemon = result.data {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Stale status indicator
                                    HStack {
                                        Circle()
                                            .fill(result.isStale ? Color.orange : Color.green)
                                            .frame(width: 8, height: 8)

                                        Text(result.isStale ? "Data is stale" : "Data is fresh")
                                            .font(.caption)
                                            .foregroundColor(result.isStale ? .orange : .green)

                                        Spacer()

                                        if result.isStale {
                                            Button("Refresh") {
                                                Task {
                                                    _ = try? await result.refetch()
                                                }
                                            }
                                            .font(.caption)
                                            .buttonStyle(.bordered)
                                        }

                                        Text("Last updated: \(formatLastUpdated(result.dataUpdatedAt))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top)

                                    PokemonDetailContent(pokemon: pokemon)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("Search for Pokemon")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text(
                            "Start typing a Pokemon name (like 'pikachu') or ID number. " +
                                "Search will start automatically after 2+ characters."
                        )
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .navigationTitle("Search Pokemon")
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
        .onDisappear {
            // Cancel any pending search task when view disappears
            searchTask?.cancel()
        }
    }

    private func throttledSearch(_ text: String) {
        // Cancel previous search task
        searchTask?.cancel()

        // Create new search task with delay
        searchTask = Task {
            // Wait for 500ms to throttle the search
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Perform search on main actor
            await MainActor.run {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedText.count >= 2 { // Only search if at least 2 characters
                    searchKey = trimmedText
                } else if trimmedText.isEmpty {
                    searchKey = "" // Clear search if text is empty
                }
            }
        }
    }
}

// MARK: - Error View Component

struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let queryError = error as? QueryError,
               queryError.code == "NOT_FOUND" || queryError.code?.contains("4") == true {
                // API error - content not found
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Content Not Found")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("The requested content could not be found.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                // Network connection error
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(.red)

                Text("Connection Error")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Unable to load content. Please check your internet connection and try again.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Try Again") {
                    retry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Previews

#Preview("Pokemon List") {
    NavigationView {
        ContentView()
            .queryClient()
    }
}

#Preview("Loading State") {
    UseQuery(
        queryKey: "pokemon-loading",
        queryFn: { _ in
            try await Task.sleep(nanoseconds: UInt64.max)
            return Pokemon(
                id: 1,
                name: "Loading",
                height: 0,
                weight: 0,
                sprites: Pokemon.Sprites(frontDefault: nil),
                types: [],
                stats: []
            )
        }
    ) { _ in
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading Pokemon...")
                .foregroundColor(.secondary)
        }
    }
}

#Preview("Error State") {
    UseQuery(
        queryKey: "pokemon-error",
        queryFn: { _ in
            throw URLError(.notConnectedToInternet)
            return Pokemon(
                id: 1,
                name: "Error",
                height: 0,
                weight: 0,
                sprites: Pokemon.Sprites(frontDefault: nil),
                types: [],
                stats: []
            )
        }
    ) { _ in
        ErrorView(error: URLError(.notConnectedToInternet)) {
            print("Retry tapped")
        }
    }
}
