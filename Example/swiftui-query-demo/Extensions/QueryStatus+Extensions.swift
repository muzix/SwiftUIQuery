//
//  QueryStatus+Extensions.swift
//  swiftui-query-demo
//
//  Created by SwiftUI Query Team
//

import SwiftUIQuery

// MARK: - QueryStatus Extensions

extension QueryStatus {
    var description: String {
        switch self {
        case .pending: return "Pending"
        case .success: return "Success"
        case .error: return "Error"
        }
    }
}
