//
//  ContentView.swift
//  swiftui-query-demo
//
//  Created by Hoang Pham on 9/7/25.
//

import SwiftUI
import SwiftUIQuery

struct ContentView: View {

//    @Query(
//        key: [FetchUserQuery(userId: "userId")],
//        fetch: {
//            try await apiClient.fetch(FetchUserQuery(userId: "userId"))
//        },
//        staleTime: .minutes(5),
//        retry: 3,
//        select: { data in data.fragments.userFragment },
//        placeholderData: { previousData in previousData },
//        initialData: cachedUser,
//        reportOnError: .always,
//        refetchInterval: .seconds(30),
//        refetchIntervalInBackground: .minutes(1)
//        refetchOnAppears: .always
//
//
//    )

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            SwiftUIQuery.demo()
        }
    }
}

#Preview {
    ContentView()
}
