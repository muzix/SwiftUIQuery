//
//  PokemonAPI.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import Foundation

// MARK: - Pokemon API Functions

extension URL {
    /// Use this init for static URL strings to avoid using force unwrap or doing redundant error handling
    /// - Parameter string: static url ie https://www.example.com/privacy/
    init(staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            fatalError("URL is illegal: \(staticString)")
        }
        self = url
    }
}

extension URL {
    init(safeString: String) {
        guard let url = URL(string: safeString) else {
            fatalError("URL is illegal: \(safeString)")
        }
        self = url
    }
}
