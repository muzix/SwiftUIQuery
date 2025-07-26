//
//  PokemonDetailView.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

// MARK: - Pokemon Detail View

struct PokemonDetailView: View {
    let pokemon: PokemonList.PokemonListItem
    @State private var showingCacheViewer = false
    
    // Query for individual Pokemon details
    @Query<Fetcher<Pokemon>> var pokemonDetailQuery: QueryState<Pokemon>
    
    init(pokemon: PokemonList.PokemonListItem) {
        self.pokemon = pokemon
        self._pokemonDetailQuery = Query(
            "pokemon-\(pokemon.pokemonId)",
            fetch: { try await fetchPokemon(id: pokemon.pokemonId) },
            options: QueryOptions(
                staleTime: .seconds(5),  // 5 minutes
                refetchOnAppear: .ifStale
            )
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                contentView
            }
            .padding()
        }
        .navigationTitle(pokemon.name.capitalized)
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
        .attach(_pokemonDetailQuery)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        // Show skeleton during initial load (isPending)
        if pokemonDetailQuery.isPending {
            skeletonView
        } else if let pokemon = pokemonDetailQuery.data {
            pokemonContentView(pokemon)
        } else if pokemonDetailQuery.error != nil {
            emptyView
        } else {
            emptyView
        }
    }
    
    // MARK: - Skeleton View
    
    private var skeletonView: some View {
        VStack(spacing: 20) {
            // Pokemon image skeleton - exact same dimensions
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 200)
                .shimmer()
            
            // Basic info skeleton
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 34) // largeTitle height
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 20) // title3 height
                    .shimmer()
            }
            
            // Types skeleton
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 36)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 36)
                    .shimmer()
            }
            
            // Physical stats skeleton
            GroupBox("Physical Stats") {
                HStack(spacing: 40) {
                    VStack {
                        Text("Height")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 20)
                            .shimmer()
                    }
                    
                    VStack {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 20)
                            .shimmer()
                    }
                }
            }
            
            // Base stats skeleton
            GroupBox("Base Stats") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 16)
                                .shimmer()
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                                .shimmer()
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 16)
                                .shimmer()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            // Center content within same height as skeleton/content
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Pokemon Not Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Unable to load Pokemon details. Please try again.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Try Again") {
                    _pokemonDetailQuery.refetch()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .frame(minHeight: 600) // Match approximate content height
    }
    
    private func pokemonContentView(_ pokemon: Pokemon) -> some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            VStack(spacing: 20) {
                pokemonImageView(pokemon)
                pokemonBasicInfoView(pokemon)
                pokemonTypesView(pokemon)
                pokemonPhysicalStatsView(pokemon)
                pokemonBaseStatsView(pokemon)
                
                // Manual refetch button
                Button {
                    _pokemonDetailQuery.refetch()
                } label: {
                    HStack {
                        if pokemonDetailQuery.isFetching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(pokemonDetailQuery.isFetching ? "Refreshing..." : "Refresh Pokemon")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pokemonDetailQuery.isFetching)
                
                // Debug status info
                statusDebugView
            }
            
            // Background refetch indicator
            if pokemonDetailQuery.isRefetching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)
                }
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
        }
    }
    
    // MARK: - Debug Status View
    
    private var statusDebugView: some View {
        GroupBox("Query Status (Debug)") {
            VStack(spacing: 4) {
                HStack {
                    Text("isPending:")
                        .font(.caption.monospaced())
                    Spacer()
                    Text(pokemonDetailQuery.isPending ? "true" : "false")
                        .font(.caption.monospaced())
                        .foregroundColor(pokemonDetailQuery.isPending ? .blue : .secondary)
                }
                
                HStack {
                    Text("isLoading:")
                        .font(.caption.monospaced())
                    Spacer()
                    Text(pokemonDetailQuery.isLoading ? "true" : "false")
                        .font(.caption.monospaced())
                        .foregroundColor(pokemonDetailQuery.isLoading ? .blue : .secondary)
                }
                
                HStack {
                    Text("isFetching:")
                        .font(.caption.monospaced())
                    Spacer()
                    Text(pokemonDetailQuery.isFetching ? "true" : "false")
                        .font(.caption.monospaced())
                        .foregroundColor(pokemonDetailQuery.isFetching ? .orange : .secondary)
                }
                
                HStack {
                    Text("isRefetching:")
                        .font(.caption.monospaced())
                    Spacer()
                    Text(pokemonDetailQuery.isRefetching ? "true" : "false")
                        .font(.caption.monospaced())
                        .foregroundColor(pokemonDetailQuery.isRefetching ? .orange : .secondary)
                }
                
                HStack {
                    Text("isFetched:")
                        .font(.caption.monospaced())
                    Spacer()
                    Text(pokemonDetailQuery.isFetched ? "true" : "false")
                        .font(.caption.monospaced())
                        .foregroundColor(pokemonDetailQuery.isFetched ? .green : .secondary)
                }
            }
        }
    }
    
    private func pokemonImageView(_ pokemon: Pokemon) -> some View {
        AsyncImage(url: URL(string: pokemon.sprites.front_default ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }
        .frame(width: 200, height: 200)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func pokemonBasicInfoView(_ pokemon: Pokemon) -> some View {
        VStack(spacing: 8) {
            Text(pokemon.name.capitalized)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("National №\(String(format: "%03d", pokemon.id))")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    private func pokemonTypesView(_ pokemon: Pokemon) -> some View {
        HStack(spacing: 12) {
            ForEach(pokemon.types, id: \.type.name) { pokemonType in
                Text(pokemonType.type.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(typeColor(for: pokemonType.type.name))
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
        }
    }
    
    private func pokemonPhysicalStatsView(_ pokemon: Pokemon) -> some View {
        GroupBox("Physical Stats") {
            HStack(spacing: 40) {
                VStack {
                    Text("Height")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Double(pokemon.height) / 10.0, specifier: "%.1f") m")
                        .font(.headline)
                }
                
                VStack {
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Double(pokemon.weight) / 10.0, specifier: "%.1f") kg")
                        .font(.headline)
                }
            }
        }
    }
    
    private func pokemonBaseStatsView(_ pokemon: Pokemon) -> some View {
        GroupBox("Base Stats") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(pokemon.stats, id: \.stat.name) { stat in
                    statRowView(stat)
                }
            }
        }
    }
    
    private func statRowView(_ stat: Pokemon.Stat) -> some View {
        HStack {
            Text(formatStatName(stat.stat.name))
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)
            
            ProgressView(value: Double(stat.base_stat), total: 255)
                .tint(statColor(for: stat.stat.name))
            
            Text("\(stat.base_stat)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Shimmer Effect Extension

extension View {
    func shimmer() -> some View {
        self.overlay(
            ShimmerView()
        )
        .clipped()
    }
}

struct ShimmerView: View {
    @State private var startAnimation = false
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .rotationEffect(.degrees(-70))
            .offset(x: startAnimation ? 400 : -400)
            .animation(
                Animation
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                value: startAnimation
            )
            .onAppear {
                startAnimation = true
            }
    }
}
