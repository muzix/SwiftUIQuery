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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .queryClient(QueryClient()) // Provide QueryClient to entire app
        }
    }
}
