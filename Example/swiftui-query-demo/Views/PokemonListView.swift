//
//  PokemonListView.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

// MARK: - Pokemon List View

struct PokemonListView: View {
    let listQuery: QueryState<PokemonList>
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Query Status
            HStack {
                Text("Query Status:")
                    .fontWeight(.medium)
                Text(listQuery.status.description)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
                if listQuery.isFetching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Additional Status Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Is Loading:")
                    Text(listQuery.isLoading ? "Yes" : "No")
                        .foregroundColor(listQuery.isLoading ? .orange : .secondary)
                }
                .font(.caption)
                
                HStack {
                    Text("Is Stale:")
                    Text(listQuery.isStale ? "Yes" : "No")
                        .foregroundColor(listQuery.isStale ? .orange : .secondary)
                }
                .font(.caption)
                
                HStack {
                    Text("Has Data:")
                    Text(listQuery.hasData ? "Yes" : "No")
                        .foregroundColor(listQuery.hasData ? .green : .secondary)
                }
                .font(.caption)
            }
            
            Divider()
            
            // Data Display
            if let pokemonList = listQuery.data {
                Text("🎉 Loaded \(pokemonList.results.count) Pokemon")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(pokemonList.results) { pokemon in
                        Button {
                            navigationPath.append(NavigationDestination.pokemonDetail(pokemon))
                        } label: {
                            VStack {
                                Text(pokemon.name.capitalized)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text("#\(pokemon.pokemonId)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let error = listQuery.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text("❌ Error occurred:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statusColor: Color {
        switch listQuery.status {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
}