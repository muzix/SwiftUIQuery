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
        if pokemonDetailQuery.isLoading {
            loadingView
        } else if let pokemon = pokemonDetailQuery.data {
            pokemonContentView(pokemon)
        } else if let error = pokemonDetailQuery.error {
            errorView(error)
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading Pokemon...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
    }
    
    private func pokemonContentView(_ pokemon: Pokemon) -> some View {
        VStack(spacing: 20) {
            pokemonImageView(pokemon)
            pokemonBasicInfoView(pokemon)
            pokemonTypesView(pokemon)
            pokemonPhysicalStatsView(pokemon)
            pokemonBaseStatsView(pokemon)
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
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to load Pokemon")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                _pokemonDetailQuery.refetch()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
