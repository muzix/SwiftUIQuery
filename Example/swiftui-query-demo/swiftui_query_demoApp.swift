//
//  swiftui_query_demoApp.swift
//  swiftui-query-demo
//
//  Created by Hoang Pham on 9/7/25.
//

import SwiftUI
import SwiftUIQuery

@main
struct swiftui_query_demoApp: App {
    // Create a global QueryClient instance
    let queryClient = QueryClient(defaultOptions: QueryOptions(
        staleTime: .seconds(30),  // 30 seconds default stale time
        refetchOnAppear: .ifStale
    ))
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .queryClient(queryClient)  // Provide QueryClient to the entire app
        }
    }
}
