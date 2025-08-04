//
//  swiftui_query_demoApp.swift
//  swiftui-query-demo
//
//  Created by Hoang Pham on 9/7/25.
//

import SwiftUI
import SwiftUIQuery

@main
struct SwiftUIQueryDemoApp: App {
    init() {
        // Enable cache logging for the demo to show SwiftUI Query in action
        QueryLogger.shared.enableAll()
        // swiftlint:disable:next no_print_statements
        print("🚀 SwiftUI Query Demo Started - Cache logging enabled!")
        // swiftlint:disable:next no_print_statements
        print("💡 Watch the console to see cache hits, misses, and state changes")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .queryClient(QueryClient()) // Provide QueryClient to entire app
        }
    }
}
