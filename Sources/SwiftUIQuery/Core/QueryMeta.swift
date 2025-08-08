import Foundation

// MARK: - Query Metadata

/// Arbitrary metadata that can be attached to queries
/// Equivalent to TanStack Query's QueryMeta
public typealias QueryMeta = [String: AnyCodable]

/// Helper type for storing any Sendable Codable value in QueryMeta
public struct AnyCodable: Sendable, Codable, Hashable {
    private let stringValue: String
    private let encode: @Sendable (Encoder) throws -> Void

    public init(_ value: some Codable & Sendable) {
        self.stringValue = String(describing: value)
        self.encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedString = try container.decode(String.self)
        self.stringValue = decodedString
        self.encode = { encoder in
            try decodedString.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}
