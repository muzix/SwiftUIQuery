//
//  ViewLifecycleAttachable.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import SwiftUI

// MARK: - View Lifecycle Attachable

/// Protocol for types that can respond to view lifecycle events
@MainActor
public protocol ViewLifecycleAttachable {
    /// Called when the view appears
    func onAppear()

    /// Called when the view disappears
    func onDisappear()
}

// MARK: - Attach View Modifier

/// View modifier that attaches lifecycle events to ViewLifecycleAttachable types
public struct AttachLifecycleModifier<Item: ViewLifecycleAttachable>: ViewModifier {
    let item: Item

    public init(item: Item) {
        self.item = item
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                item.onAppear()
            }
            .onDisappear {
                item.onDisappear()
            }
    }
}

// MARK: - View Extension

extension View {
    /// Attach lifecycle events from this view to a ViewLifecycleAttachable item
    /// - Parameter item: The item to receive lifecycle events
    /// - Returns: A view that forwards lifecycle events to the item
    public func attach(_ item: some ViewLifecycleAttachable) -> some View {
        modifier(AttachLifecycleModifier(item: item))
    }
}
