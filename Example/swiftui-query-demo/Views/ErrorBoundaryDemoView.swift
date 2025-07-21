//
//  ErrorBoundaryDemoView.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUI
import SwiftUIQuery

struct ErrorBoundaryDemoView: View {
    @Environment(\.queryClient) private var queryClient
    @State private var showingCacheViewer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                // Demo 1: Basic Error Boundary
                basicErrorBoundaryDemo
                
                // Demo 2: Custom Error View
                customErrorViewDemo
                
                // Demo 3: Multiple Error Boundaries (Nested)
                nestedErrorBoundariesDemo
                
                // Demo 4: Conditional Error Throwing
                conditionalErrorDemo
                
                // Demo 5: FetchProtocol Error Boundary
                fetchProtocolErrorDemo
                
                globalActionsSection
            }
            .padding()
        }
        .navigationTitle("Error Boundary Demo")
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
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Error Boundary Demo")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("✨ SwiftUI Query Error Boundaries!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                Text("Similar to React Error Boundaries, these catch and handle errors from child queries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Basic Error Boundary Demo
    
    private var basicErrorBoundaryDemo: some View {
        GroupBox("Basic Error Boundary") {
            VStack(spacing: 16) {
                Text("This query will always fail and throw errors to the error boundary")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                BasicErrorQuery()
                    .errorBoundary {
                        print("🔄 Error boundary reset triggered")
                        Task {
                            await queryClient?.invalidateQueries(filter: .key("error-demo-basic"))
                        }
                    }
            }
        }
    }
    
    // MARK: - Custom Error View Demo
    
    private var customErrorViewDemo: some View {
        GroupBox("Custom Error View") {
            VStack(spacing: 16) {
                Text("This demo shows a custom error view with different styling")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                CustomErrorQuery()
                    .errorBoundary(resetAction: {
                        print("🎨 Custom error boundary reset")
                    }) { error, retry in
                        CustomErrorView(error: error, retry: retry)
                    }
            }
        }
    }
    
    // MARK: - Nested Error Boundaries Demo
    
    private var nestedErrorBoundariesDemo: some View {
        GroupBox("Nested Error Boundaries") {
            VStack(spacing: 16) {
                Text("Multiple error boundaries can be nested - inner boundaries catch first")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Text("Outer Boundary")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Inner Boundary")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        
                        NestedErrorQuery()
                            .errorBoundary(resetAction: {
                                print("💜 Inner boundary reset")
                            }) { error, retry in
                                InnerBoundaryErrorView(error: error, retry: retry)
                            }
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .errorBoundary(resetAction: {
                    print("💙 Outer boundary reset")
                }) { error, retry in
                    OuterBoundaryErrorView(error: error, retry: retry)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Conditional Error Demo
    
    private var conditionalErrorDemo: some View {
        GroupBox("Conditional Error Throwing") {
            VStack(spacing: 16) {
                Text("This query only throws network errors to boundary, handles validation errors inline")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                ConditionalErrorQuery()
                    .errorBoundary {
                        print("🎯 Only network errors reach here")
                    }
            }
        }
    }
    
    // MARK: - FetchProtocol Error Demo
    
    private var fetchProtocolErrorDemo: some View {
        GroupBox("FetchProtocol Error Boundary") {
            VStack(spacing: 16) {
                Text("Demonstrates error boundaries with dynamic FetchProtocol objects and configurable refetch")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                FetchProtocolErrorQuery()
                    .errorBoundary {
                        print("🔧 FetchProtocol error boundary reset")
                    }
            }
        }
    }
    
    // MARK: - Global Actions
    
    private var globalActionsSection: some View {
        GroupBox("Global Error Actions") {
            VStack(spacing: 12) {
                Text("Manage all error-prone queries globally")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Button("Invalidate All Error Queries") {
                        Task {
                            await queryClient?.invalidateQueries(
                                filter: .predicate { key in
                                    key.stringValue.contains("error-demo")
                                }
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                    
                    Button("Reset All Error Queries") {
                        queryClient?.resetQueries(
                            filter: .predicate { key in
                                key.stringValue.contains("error-demo")
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

// MARK: - Basic Error Query

struct BasicErrorQuery: View {
    @Query(
        "error-demo-basic",
        fetch: {
            try await Task.sleep(for: .seconds(1))
            throw DemoError.alwaysFails("Basic error boundary test")
        },
        options: QueryOptions(
            retry: 0, // Don't retry for demo purposes
            reportOnError: .always
        )
    ) var errorQuery

    var body: some View {
        VStack(spacing: 12) {
            switch errorQuery.status {
            case .idle:
                Text("Ready to trigger error.")
                    .foregroundColor(.gray)
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading (will fail)...")
                }
            case .success:
                Text("This shouldn't happen!")
                    .foregroundColor(.green)
            case .error:
                // This shouldn't show since error is thrown to boundary
                Text("Error in component (shouldn't see this)")
                    .foregroundColor(.red)
            }
            
            Button("Trigger Error") {
                _errorQuery.refetch()
            }
            .buttonStyle(.borderedProminent)
        }
        .attach(_errorQuery)
    }
}

// MARK: - Custom Error Query

struct CustomErrorQuery: View {
    @Query(
        "error-demo-custom",
        fetch: {
            try await Task.sleep(for: .seconds(1))
            throw DemoError.customUIError("This error has a custom UI")
        },
        options: QueryOptions(
            retry: 0,
            reportOnError: .always
        )
    ) var errorQuery
    
    var body: some View {
        VStack(spacing: 12) {
            switch errorQuery.status {
            case .idle:
                Text("Ready for custom error UI")
                    .foregroundColor(.gray)
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading custom error...")
                }
            case .success, .error:
                Text("Waiting for error boundary...")
            }
            
            Button("Trigger Custom Error") {
                _errorQuery.refetch()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .attach(_errorQuery)
    }
}

// MARK: - Nested Error Query

struct NestedErrorQuery: View {
    @Query(
        "error-demo-nested",
        fetch: {
            try await Task.sleep(for: .seconds(1))
            throw DemoError.innerBoundaryError("Inner boundary should catch this")
        },
        options: QueryOptions(
            retry: 0,
            reportOnError: .always
        )
    ) var errorQuery
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Nested Query Status: \(statusText)")
                .font(.caption2)
                .foregroundColor(.purple)
            
            Button("Trigger Nested Error") {
                _errorQuery.refetch()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .attach(_errorQuery)
    }
    
    private var statusText: String {
        switch errorQuery.status {
        case .idle: return "IDLE"
        case .loading: return "LOADING"
        case .success: return "SUCCESS"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Conditional Error Query

struct ConditionalErrorQuery: View {
    @State private var errorType: ConditionalErrorType = .validation
    
    @Query<Fetcher<String>> var conditionalQuery: QueryState<String>

    init() {
        self._conditionalQuery = Query(
            "error-demo-conditional",
            fetch: { @MainActor in
                try await Task.sleep(for: .seconds(1))
                
                // Simulate different error types
                if Bool.random() {
                    throw DemoError.networkError("Network connection failed")
                } else {
                    throw DemoError.validationError("Invalid input data")
                }
            },
            options: QueryOptions(
                retry: 0,
                reportOnError: .when { error in
                    // Only throw network errors to boundary
                    if let demoError = error as? DemoError {
                        switch demoError {
                        case .networkError:
                            return true
                        case .validationError:
                            return false
                        default:
                            return false
                        }
                    }
                    return false
                }
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            switch conditionalQuery.status {
            case .idle:
                Text("Random error type (network → boundary, validation → inline)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading (random error)...")
                }
            case .success:
                Text("Success: \(conditionalQuery.data ?? "No data")")
                    .foregroundColor(.green)
            case .error:
                // Only validation errors show here
                if let error = conditionalQuery.error {
                    VStack(spacing: 8) {
                        Text("Inline Error:")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button("Trigger Random Error") {
                _conditionalQuery.refetch()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .attach(_conditionalQuery)
    }
}

// MARK: - FetchProtocol Error Query

struct FetchProtocolErrorQuery: View {
    @State private var searchText = ""
    @StateObject private var errorFetcher = ErrorProneSearchFetcher()
    
    @Query<ErrorProneSearchFetcher> var errorQuery: QueryState<SearchResult>
    
    init() {
        let fetcher = ErrorProneSearchFetcher()
        self._errorFetcher = StateObject(wrappedValue: fetcher)
        self._errorQuery = Query(
            "error-demo-fetchprotocol",
            fetcher: fetcher,
            options: QueryOptions(
                retry: 0,
                reportOnError: .when { error in
                    // Only throw network errors to boundary
                    if let searchError = error as? SearchError {
                        return searchError.isNetworkError
                    }
                    return false
                }
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Controls
            VStack(spacing: 12) {
                TextField("Try: 'error', 'network', 'server', 'timeout'", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: searchText) { _, newValue in
                        errorFetcher.searchTerm = newValue
                    }
                
                HStack {
                    Toggle("Network Error", isOn: $errorFetcher.simulateNetworkError)
                        .font(.caption)
                    Toggle("Server Error", isOn: $errorFetcher.simulateServerError)
                        .font(.caption)
                }
                .toggleStyle(.switch)
            }
            
            // Status Display
            VStack(spacing: 8) {
                Text("Status: \(statusText)")
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                switch errorQuery.status {
                case .idle:
                    Text("Enter a search term to test error boundaries")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .loading:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                    }
                case .success:
                    if let result = errorQuery.data {
                        VStack(spacing: 4) {
                            Text("✅ Results for '\(result.query)':")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(result.results.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                case .error:
                    // Only validation errors show here (network errors go to boundary)
                    if let error = errorQuery.error {
                        VStack(spacing: 4) {
                            Text("⚠️ Validation Error (handled inline):")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(error.localizedDescription)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .frame(minHeight: 60)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Search Current") {
                    _errorQuery.refetch()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .disabled(searchText.isEmpty)
                
                Button("Search 'error'") {
                    _errorQuery.refetch { $0.searchTerm = "error" }
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Button("Search 'network'") {
                    _errorQuery.refetch { $0.searchTerm = "network" }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            
            // Fetcher State Info
            VStack(spacing: 4) {
                Text("Fetcher State:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Term: '\(errorFetcher.searchTerm)'")
                    .font(.caption2)
                    .foregroundColor(.purple)
                Text("Network: \(errorFetcher.simulateNetworkError), Server: \(errorFetcher.simulateServerError)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .attach(_errorQuery)
    }
    
    private var statusText: String {
        switch errorQuery.status {
        case .idle: return "IDLE"
        case .loading: return "LOADING"
        case .success: return "SUCCESS"
        case .error: return "ERROR (INLINE)"
        }
    }
    
    private var statusColor: Color {
        switch errorQuery.status {
        case .idle: return .gray
        case .loading: return .blue
        case .success: return .green
        case .error: return .orange
        }
    }
}

// MARK: - Demo Errors

enum DemoError: Error, LocalizedError {
    case alwaysFails(String)
    case customUIError(String)
    case innerBoundaryError(String)
    case networkError(String)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .alwaysFails(let message):
            return "Always Fails: \(message)"
        case .customUIError(let message):
            return "Custom UI Error: \(message)"
        case .innerBoundaryError(let message):
            return "Inner Boundary: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        }
    }
}

enum ConditionalErrorType {
    case network
    case validation
}

// MARK: - Custom Error Views

struct CustomErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "paintbrush.pointed")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Error UI")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    Text("This is a custom styled error view")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            
            HStack {
                Button("Dismiss") {
                    // Could dismiss without retry
                }
                .buttonStyle(.bordered)
                
                Button("Try Again") {
                    retry()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .purple.opacity(0.2), radius: 8)
    }
}

struct InnerBoundaryErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.purple)
                Text("Inner Boundary Caught")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
            }
            
            Text(error.localizedDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry Inner") {
                retry()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(8)
        .background(Color.purple.opacity(0.2))
        .cornerRadius(6)
    }
}

struct OuterBoundaryErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.blue)
                Text("Outer Boundary Caught")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            Text("This error bubbled up to the outer boundary")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(error.localizedDescription)
                .font(.caption2)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Button("Retry Outer") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(12)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }
}

#Preview {
    let queryClient = QueryClient()
    
    return NavigationStack {
        ErrorBoundaryDemoView()
    }
    .queryClient(queryClient)
}
