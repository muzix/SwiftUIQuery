import Foundation

// MARK: - QueryKey Protocol

/// A protocol that represents a unique identifier for queries
/// Equivalent to TanStack Query's QueryKey (ReadonlyArray<unknown>)
public protocol QueryKey: Sendable, Hashable, Codable {
    /// Convert the query key to a string hash for identification
    var queryHash: String { get }
}

/// Default QueryKey implementation using arrays of strings
public struct ArrayQueryKey: QueryKey {
    public let components: [String]

    public init(_ components: String...) {
        self.components = components
    }

    public init(_ components: [String]) {
        self.components = components
    }

    public var queryHash: String {
        // Create a deterministic hash similar to TanStack Query's approach
        guard let jsonData = try? JSONEncoder().encode(components.sorted()),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return components.sorted().joined(separator: "|")
        }
        return jsonString
    }
}

/// Generic QueryKey implementation for any Codable type
public struct GenericQueryKey<T: Sendable & Codable & Hashable>: QueryKey {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public var queryHash: String {
        guard let jsonData = try? JSONEncoder().encode(value),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return String(describing: value)
        }
        return jsonString
    }
}

// MARK: - QueryKey Extensions for Common Types

extension String: QueryKey {
    public var queryHash: String {
        self
    }
}

extension [String]: QueryKey {
    public var queryHash: String {
        // Create a deterministic hash by joining sorted components
        sorted().joined(separator: "|")
    }
}
