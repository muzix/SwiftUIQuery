import Foundation

// MARK: - QueryKey Protocol

/// A protocol that represents a unique identifier for queries
/// Equivalent to TanStack Query's QueryKey (ReadonlyArray<unknown>)
public protocol QueryKey: Sendable, Equatable {
    /// Convert the query key to a string hash for identification
    var queryHash: String { get }
}

extension QueryKey where Self: Hashable & Codable {
    public var queryHash: String {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .sortedKeys // stable output with key sorted
        guard let jsonData = try? jsonEncoder.encode(self) else {
            return "\(hashValue)"
        }
        return String(decoding: jsonData, as: UTF8.self)
    }
}

// MARK: - QueryKey Extensions for Common Types

extension String: QueryKey {
    public var queryHash: String {
        self
    }
}

extension Array: QueryKey where Element: Hashable & Codable {}
extension Dictionary: QueryKey where Key: Hashable & Codable, Value: Hashable & Codable {}

public typealias QueryKeyCodable = Codable & Hashable & Sendable
public struct KeyTuple2<K1: QueryKeyCodable, K2: QueryKeyCodable>: QueryKey, QueryKeyCodable {
    public let key1: K1
    public let key2: K2

    public init(_ key1: K1, _ key2: K2) {
        self.key1 = key1
        self.key2 = key2
    }

    public init(_ key1: (some Any).Type, _ key2: K2) where K1 == String {
        self.key1 = String(describing: key1)
        self.key2 = key2
    }
}

public struct KeyTuple3<K1: QueryKeyCodable, K2: QueryKeyCodable, K3: QueryKeyCodable>: QueryKey, QueryKeyCodable {
    public let key1: K1
    public let key2: K2
    public let key3: K3

    public init(_ key1: K1, _ key2: K2, _ key3: K3) {
        self.key1 = key1
        self.key2 = key2
        self.key3 = key3
    }

    public init(_ key1: (some Any).Type, _ key2: K2, _ key3: K3) where K1 == String {
        self.key1 = String(describing: key1)
        self.key2 = key2
        self.key3 = key3
    }
}

public struct KeyTuple4<K1: QueryKeyCodable, K2: QueryKeyCodable, K3: QueryKeyCodable, K4: QueryKeyCodable>: QueryKey,
    QueryKeyCodable {
    public let key1: K1
    public let key2: K2
    public let key3: K3
    public let key4: K4

    public init(_ key1: K1, _ key2: K2, _ key3: K3, _ key4: K4) {
        self.key1 = key1
        self.key2 = key2
        self.key3 = key3
        self.key4 = key4
    }

    public init(_ key1: (some Any).Type, _ key2: K2, _ key3: K3, _ key4: K4) where K1 == String {
        self.key1 = String(describing: key1)
        self.key2 = key2
        self.key3 = key3
        self.key4 = key4
    }
}

public struct KeyTuple5<
    K1: QueryKeyCodable,
    K2: QueryKeyCodable,
    K3: QueryKeyCodable,
    K4: QueryKeyCodable,
    K5: QueryKeyCodable
>: QueryKey,
    QueryKeyCodable {
    public let key1: K1
    public let key2: K2
    public let key3: K3
    public let key4: K4
    public let key5: K5

    public init(_ key1: K1, _ key2: K2, _ key3: K3, _ key4: K4, _ key5: K5) {
        self.key1 = key1
        self.key2 = key2
        self.key3 = key3
        self.key4 = key4
        self.key5 = key5
    }

    public init(_ key1: (some Any).Type, _ key2: K2, _ key3: K3, _ key4: K4, _ key5: K5) where K1 == String {
        self.key1 = String(describing: key1)
        self.key2 = key2
        self.key3 = key3
        self.key4 = key4
        self.key5 = key5
    }
}

public struct KeyTuple6<
    K1: QueryKeyCodable,
    K2: QueryKeyCodable,
    K3: QueryKeyCodable,
    K4: QueryKeyCodable,
    K5: QueryKeyCodable,
    K6: QueryKeyCodable
>: QueryKey,
    QueryKeyCodable {
    public let key1: K1
    public let key2: K2
    public let key3: K3
    public let key4: K4
    public let key5: K5
    public let key6: K6

    public init(_ key1: K1, _ key2: K2, _ key3: K3, _ key4: K4, _ key5: K5, _ key6: K6) {
        self.key1 = key1
        self.key2 = key2
        self.key3 = key3
        self.key4 = key4
        self.key5 = key5
        self.key6 = key6
    }

    public init(_ key1: (some Any).Type, _ key2: K2, _ key3: K3, _ key4: K4, _ key5: K5, _ key6: K6)
        where K1 == String {
        self.key1 = String(describing: key1)
        self.key2 = key2
        self.key3 = key3
        self.key4 = key4
        self.key5 = key5
        self.key6 = key6
    }
}
