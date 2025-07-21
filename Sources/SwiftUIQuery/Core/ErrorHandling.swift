//
//  ErrorHandling.swift
//  SwiftUIQuery
//
//  Created by SwiftUI Query Team
//

import Foundation
import SwiftUI

// MARK: - ReportError Environment

/// Sendable wrapper for error reporting functionality
public struct ReportErrorAction: Sendable {
    public typealias Action = @MainActor @Sendable (Error) -> Void
    let action: Action
    
    public init(action: @escaping Action) {
        self.action = action
    }
    
    @MainActor
    public func callAsFunction(_ error: Error) {
        action(error)
    }
}

extension EnvironmentValues {
    /// Access to the error reporting function from the environment
    @Entry public var reportError = ReportErrorAction { _ in }
}

// MARK: - ErrorBoundary View Modifier

/// A SwiftUI view modifier that provides error boundary functionality similar to React Error Boundaries
public struct ErrorBoundary: ViewModifier {
    @State private var error: Error?
    private let resetAction: () -> Void
    private let errorView: (Error, @escaping () -> Void) -> AnyView
    
    /// Initialize an error boundary
    /// - Parameters:
    ///   - resetAction: Action to call when retrying after an error
    ///   - errorView: Custom view to display when an error occurs
    public init(
        resetAction: @escaping () -> Void,
        @ViewBuilder errorView: @escaping (Error, @escaping () -> Void) -> some View = { error, retry in
            DefaultErrorView(error: error, retry: retry)
        }
    ) {
        self.resetAction = resetAction
        self.errorView = { error, retry in AnyView(errorView(error, retry)) }
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            // Always keep the content active (but hide it when showing error)
            content
                .opacity(error == nil ? 1 : 0)
                .environment(\.reportError, ReportErrorAction { @MainActor error in
                    self.error = error
                })
            
            // Show error view on top when there's an error
            if let error = error {
                errorView(error) {
                    self.error = nil
                    resetAction()
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Default Error View

/// Default error view displayed by ErrorBoundary
public struct DefaultErrorView: View {
    let error: Error
    let retry: () -> Void
    
    public init(error: Error, retry: @escaping () -> Void) {
        self.error = error
        self.retry = retry
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - View Extension

extension View {
    /// Add an error boundary to this view
    /// - Parameters:
    ///   - resetAction: Action to call when retrying after an error
    ///   - errorView: Custom view to display when an error occurs
    /// - Returns: A view wrapped with error boundary functionality
    public func errorBoundary(
        resetAction: @escaping () -> Void,
        @ViewBuilder errorView: @escaping (Error, @escaping () -> Void) -> some View = { error, retry in
            DefaultErrorView(error: error, retry: retry)
        }
    ) -> some View {
        modifier(ErrorBoundary(resetAction: resetAction, errorView: errorView))
    }
    
    /// Add a simple error boundary with default error view
    /// - Parameter resetAction: Action to call when retrying after an error
    /// - Returns: A view wrapped with error boundary functionality
    public func errorBoundary(resetAction: @escaping () -> Void) -> some View {
        modifier(ErrorBoundary(resetAction: resetAction))
    }
}