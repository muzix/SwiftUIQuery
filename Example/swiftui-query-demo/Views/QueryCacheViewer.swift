//
//  QueryCacheViewer.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

struct QueryCacheViewer: View {
    @Environment(\.queryClient) private var queryClient
    @Environment(\.dismiss) private var dismiss
    @State private var queries: [AnyQueryInstance] = []
    @State private var refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var refreshTrigger = false
    @State private var sortOption: SortOption = .key
    @State private var filterOption: FilterOption = .all
    
    enum SortOption: String, CaseIterable {
        case key = "Key"
        case status = "Status"
        case active = "Active"
        case lastUpdated = "Last Updated"
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
        case loading = "Loading"
        case success = "Success"
        case error = "Error"
        case stale = "Stale"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Refresh trigger for UI updates
                if refreshTrigger {
                    EmptyView().hidden()
                } else {
                    EmptyView().hidden()
                }
                
                // Header Stats
                headerStats
                
                // Filter and Sort Controls
                controlsSection
                
                // Query List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedAndFilteredQueries, id: \.key.hashKey) { query in
                            QueryCacheItem(query: query)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Query Cache Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Invalidate All") {
                            Task {
                                await queryClient?.invalidateQueries()
                                refreshQueries()
                            }
                        }
                        
                        Button("Refetch All Active") {
                            Task {
                                await queryClient?.invalidateQueries(refetchType: .active)
                                refreshQueries()
                            }
                        }
                        
                        Button("Reset All") {
                            queryClient?.resetQueries()
                            refreshQueries()
                        }
                        
                        Divider()
                        
                        Button("Clear Cache", role: .destructive) {
                            queryClient?.clear()
                            refreshQueries()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                refreshQueries()
            }
            .onReceive(refreshTimer) { _ in
                refreshTrigger.toggle()
                refreshQueries()
            }
        }
    }
    
    // MARK: - Header Stats
    
    private var headerStats: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                StatBadge(
                    title: "Total",
                    value: "\(queries.count)",
                    color: .blue
                )
                
                StatBadge(
                    title: "Active",
                    value: "\(queries.filter { $0.isActive() }.count)",
                    color: .green
                )
                
                StatBadge(
                    title: "Loading",
                    value: "\(queries.filter { $0.isFetching() }.count)",
                    color: .orange
                )
                
                StatBadge(
                    title: "Stale",
                    value: "\(queries.filter { $0.isStale() }.count)",
                    color: .yellow
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Filter Picker
            Picker("Filter", selection: $filterOption) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            
            // Sort Picker
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Sorted and Filtered Queries
    
    private var sortedAndFilteredQueries: [AnyQueryInstance] {
        let filtered = queries.filter { query in
            switch filterOption {
            case .all:
                return true
            case .active:
                return query.isActive()
            case .inactive:
                return !query.isActive()
            case .loading:
                return query.isFetching()
            case .success:
                return query.getStatus() == .success
            case .error:
                return query.getStatus() == .error
            case .stale:
                return query.isStale()
            }
        }
        
        return filtered.sorted { q1, q2 in
            switch sortOption {
            case .key:
                return q1.key.stringValue < q2.key.stringValue
            case .status:
                return statusSortValue(q1.getStatus()) < statusSortValue(q2.getStatus())
            case .active:
                return q1.isActive() && !q2.isActive()
            case .lastUpdated:
                let date1 = q1.dataUpdatedAt() ?? Date.distantPast
                let date2 = q2.dataUpdatedAt() ?? Date.distantPast
                return date1 > date2
            }
        }
    }
    
    private func statusSortValue(_ status: QueryStatus) -> Int {
        switch status {
        case .loading: return 0
        case .error: return 1
        case .success: return 2
        case .idle: return 3
        }
    }
    
    // MARK: - Actions
    
    private func refreshQueries() {
        queries = queryClient?.getAllQueries() ?? []
    }
}

// MARK: - Query Cache Item

struct QueryCacheItem: View {
    let query: AnyQueryInstance
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    // Status Indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    
                    // Key
                    VStack(alignment: .leading, spacing: 4) {
                        Text(query.key.stringValue)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            // Status
                            StatusBadge(status: query.getStatus())
                            
                            // Active/Inactive
                            if query.isActive() {
                                Badge(text: "ACTIVE", color: .green)
                            } else {
                                Badge(text: "INACTIVE", color: .gray)
                            }
                            
                            // Stale
                            if query.isStale() {
                                Badge(text: "STALE", color: .yellow)
                            }
                            
                            // Fetching
                            if query.isFetching() {
                                Badge(text: "FETCHING", color: .blue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Last Updated
                    if let updatedAt = query.dataUpdatedAt() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("ago")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Expand Indicator
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded Actions
            if isExpanded {
                Divider()
                
                HStack(spacing: 12) {
                    ActionButton(title: "Refetch", systemImage: "arrow.clockwise") {
                        Task { await query.fetch() }
                    }
                    
                    ActionButton(title: "Invalidate", systemImage: "exclamationmark.circle") {
                        query.invalidate()
                    }
                    
                    ActionButton(title: "Reset", systemImage: "arrow.counterclockwise") {
                        query.reset()
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch query.getStatus() {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return query.isStale() ? .yellow : .green
        case .error: return .red
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatusBadge: View {
    let status: QueryStatus
    
    var body: some View {
        Badge(
            text: statusText,
            color: statusColor
        )
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "IDLE"
        case .loading: return "LOADING"
        case .success: return "SUCCESS"
        case .error: return "ERROR"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let queryClient = QueryClient()
    
    return QueryCacheViewer()
        .environment(\.queryClient, queryClient)
}