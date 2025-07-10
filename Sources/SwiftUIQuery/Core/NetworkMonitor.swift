//
//  NetworkMonitor.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation
import Network

// MARK: - Network Monitor

/// Monitors network connectivity and posts reconnection notifications
@Observable
public final class NetworkMonitor: @unchecked Sendable {
    @MainActor public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    /// Whether the device is currently connected to the network
    public private(set) var isConnected = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                
                // Notify when reconnected (was disconnected, now connected)
                if !wasConnected && self?.isConnected == true {
                    NotificationCenter.default.post(
                        name: .networkReconnected,
                        object: nil
                    )
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the device reconnects to the network after being disconnected
    public static let networkReconnected = Notification.Name("networkReconnected")
}