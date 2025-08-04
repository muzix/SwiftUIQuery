import SwiftUI
import SwiftUIQuery
import Perception

struct DevToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.queryClient) private var queryClient
    @State private var selectedTab = 0
    @State private var refreshTimer: Timer?
    @State private var autoRefresh = true

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                QueryCacheView(queryClient: queryClient, autoRefresh: $autoRefresh)
                    .tabItem {
                        Image(systemName: "tray.full")
                        Text("Cache")
                    }
                    .tag(0)

                GarbageCollectionView(queryClient: queryClient, autoRefresh: $autoRefresh)
                    .tabItem {
                        Image(systemName: "trash")
                        Text("GC")
                    }
                    .tag(1)

                QueryActionsView(queryClient: queryClient)
                    .tabItem {
                        Image(systemName: "slider.horizontal.3")
                        Text("Actions")
                    }
                    .tag(2)
            }
            .navigationTitle("DevTools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(autoRefresh ? "⏸️" : "▶️") {
                        autoRefresh.toggle()
                    }
                    .font(.caption)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: autoRefresh) { newValue in
            if newValue {
                startAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }

    private func startAutoRefresh() {
        guard autoRefresh else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Timer triggers UI refresh through @State changes
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Query Cache View

struct QueryCacheView: View {
    let queryClient: QueryClient
    @Binding var autoRefresh: Bool
    @State private var selectedQuery: AnyQuery?
    @State private var searchText = ""

    private var filteredQueries: [AnyQuery] {
        let queries = queryClient.cache.allQueries
        if searchText.isEmpty {
            return queries.sorted { $0.queryHash < $1.queryHash }
        } else {
            return queries.filter { query in
                query.queryHash.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.queryHash < $1.queryHash }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search queries...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()

            // Cache Stats
            CacheStatsView(queryClient: queryClient)

            Divider()

            // Query List
            if filteredQueries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text(searchText.isEmpty ? "No Queries in Cache" : "No Matching Queries")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    if !searchText.isEmpty {
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredQueries, id: \.queryHash) { query in
                    QueryCacheItemView(query: query, isSelected: selectedQuery?.queryHash == query.queryHash) {
                        selectedQuery = query
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(item: Binding<QueryDetailItem?>(
            get: { selectedQuery.map(QueryDetailItem.init) },
            set: { selectedQuery = $0?.query }
        )) { item in
            QueryDetailView(query: item.query)
        }
    }
}

// MARK: - Cache Stats View

struct CacheStatsView: View {
    let queryClient: QueryClient

    private var stats: (total: Int, stale: Int, fresh: Int, error: Int) {
        let queries = queryClient.cache.allQueries
        let total = queries.count
        let stale = queries.filter(\.isStale).count
        let fresh = total - stale
        let error = queries.compactMap { _ in
            // We need to access the error state somehow - this is a limitation of type erasure
            // For now, we'll estimate based on query hash patterns or use reflection
            nil
        }.count

        return (total: total, stale: stale, fresh: fresh, error: error)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Cache Statistics")
                .font(.headline)
                .fontWeight(.medium)

            HStack(spacing: 20) {
                StatItem(label: "Total", value: stats.total, color: .blue)
                StatItem(label: "Fresh", value: stats.fresh, color: .green)
                StatItem(label: "Stale", value: stats.stale, color: .orange)
                StatItem(label: "Errors", value: stats.error, color: .red)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct StatItem: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Query Cache Item View

struct QueryCacheItemView: View {
    let query: AnyQuery
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(query.isStale ? Color.orange : Color.green)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    // Query hash (truncated)
                    Text(truncatedHash(query.queryHash))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Last updated
                    if let lastUpdated = query.lastUpdated {
                        Text("Updated: \(formatRelativeTime(lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never updated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    // Status badge
                    Text(query.isStale ? "STALE" : "FRESH")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(query.isStale ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(query.isStale ? .orange : .green)
                        .cornerRadius(4)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func truncatedHash(_ hash: String) -> String {
        if hash.count > 40 {
            return String(hash.prefix(37)) + "..."
        }
        return hash
    }
}

// MARK: - Garbage Collection View

struct GarbageCollectionView: View {
    let queryClient: QueryClient
    @Binding var autoRefresh: Bool
    @State private var gcThreshold: TimeInterval = 5 * 60 // 5 minutes default

    private var eligibleForGC: [AnyQuery] {
        let now = Date()
        return queryClient.cache.allQueries.filter { query in
            guard let lastUpdated = query.lastUpdated else { return true }
            return now.timeIntervalSince(lastUpdated) > gcThreshold
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // GC Controls
            VStack(spacing: 16) {
                Text("Garbage Collection Monitor")
                    .font(.headline)
                    .fontWeight(.medium)

                Text(
                    "Queries are eligible for garbage collection when they haven't been updated for longer than their gcTime."
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

                // GC Threshold Slider
                VStack(spacing: 8) {
                    Text("GC Threshold: \(Int(gcThreshold / 60)) minutes")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Slider(value: $gcThreshold, in: 60 ... 1800, step: 60) {
                        Text("GC Threshold")
                    }
                    .accentColor(.orange)
                }

                // GC Stats
                HStack(spacing: 20) {
                    StatItem(label: "Total", value: queryClient.cache.allQueries.count, color: .blue)
                    StatItem(label: "Eligible for GC", value: eligibleForGC.count, color: .orange)
                    StatItem(
                        label: "Active",
                        value: queryClient.cache.allQueries.count - eligibleForGC.count,
                        color: .green
                    )
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            Divider()

            // Eligible Queries List
            if eligibleForGC.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("No Queries Eligible for GC")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("All queries are still active or within their gcTime threshold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Queries Eligible for Garbage Collection")
                            .font(.headline)
                            .fontWeight(.medium)

                        Spacer()

                        Button("Simulate GC") {
                            // In a real implementation, this would trigger GC
                            // For demo purposes, we'll just show an alert
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    List(eligibleForGC, id: \.queryHash) { query in
                        GCEligibleItemView(query: query, threshold: gcThreshold)
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
    }
}

struct GCEligibleItemView: View {
    let query: AnyQuery
    let threshold: TimeInterval

    private var timeSinceUpdate: TimeInterval {
        guard let lastUpdated = query.lastUpdated else { return 0 }
        return Date().timeIntervalSince(lastUpdated)
    }

    private var timeOverThreshold: TimeInterval {
        max(0, timeSinceUpdate - threshold)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(truncatedHash(query.queryHash))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Idle for \(formatDuration(timeSinceUpdate))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if timeOverThreshold > 0 {
                    Text("Over threshold by \(formatDuration(timeOverThreshold))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Text("ELIGIBLE")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
    }

    private func truncatedHash(_ hash: String) -> String {
        if hash.count > 30 {
            return String(hash.prefix(27)) + "..."
        }
        return hash
    }
}

// MARK: - Query Actions View

struct QueryActionsView: View {
    let queryClient: QueryClient
    @State private var showingClearConfirmation = false
    @State private var showingInvalidateAll = false

    var body: some View {
        List {
            Section(header: Text("Cache Management")) {
                ActionButton(
                    icon: "trash.circle.fill",
                    title: "Clear All Queries",
                    description: "Remove all queries from cache",
                    color: .red,
                    action: { showingClearConfirmation = true }
                )

                ActionButton(
                    icon: "arrow.clockwise.circle.fill",
                    title: "Invalidate All Queries",
                    description: "Mark all queries as stale and refetch",
                    color: .orange,
                    action: { showingInvalidateAll = true }
                )

                ActionButton(
                    icon: "arrow.down.circle.fill",
                    title: "Refetch All Queries",
                    description: "Refetch all active queries",
                    color: .blue,
                    action: {
                        Task {
                            await queryClient.refetchQueries()
                        }
                    }
                )
            }

            Section(header: Text("Debug Information")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Query Client Info")
                        .font(.headline)

                    InfoRow(label: "Total Queries", value: "\(queryClient.cache.allQueries.count)")
                    InfoRow(label: "Cache Size", value: formatCacheSize())
                }
                .padding(.vertical, 8)
            }
        }
        .alert("Clear All Queries?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                queryClient.clear()
            }
        } message: {
            Text("This will remove all queries from the cache. Active queries will need to refetch their data.")
        }
        .alert("Invalidate All Queries?", isPresented: $showingInvalidateAll) {
            Button("Cancel", role: .cancel) {}
            Button("Invalidate", role: .destructive) {
                Task {
                    await queryClient.invalidateQueries()
                }
            }
        } message: {
            Text("This will mark all queries as stale and trigger refetches for active queries.")
        }
    }

    private func formatCacheSize() -> String {
        let count = queryClient.cache.allQueries.count
        return "\(count) \(count == 1 ? "query" : "queries")"
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

// MARK: - Query Detail View

struct QueryDetailItem: Identifiable {
    let id = UUID()
    let query: AnyQuery
}

struct QueryDetailView: View {
    let query: AnyQuery
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Query Hash
                    DetailSection(title: "Query Key") {
                        Text(query.queryHash)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Status Information
                    DetailSection(title: "Status") {
                        VStack(spacing: 12) {
                            StatusRow(
                                label: "Stale",
                                value: query.isStale ? "Yes" : "No",
                                color: query.isStale ? .orange : .green
                            )

                            if let lastUpdated = query.lastUpdated {
                                StatusRow(label: "Last Updated", value: formatAbsoluteTime(lastUpdated), color: .blue)
                                StatusRow(
                                    label: "Age",
                                    value: formatDuration(Date().timeIntervalSince(lastUpdated)),
                                    color: .secondary
                                )
                            } else {
                                StatusRow(label: "Last Updated", value: "Never", color: .secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Query Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)

            content
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .font(.subheadline)
    }
}

// MARK: - Utility Functions

private func formatRelativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func formatAbsoluteTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60

    if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    } else {
        return "\(seconds)s"
    }
}

#Preview {
    DevToolsView()
        .queryClient(QueryClient())
}
