import Testing
import SwiftUI
@testable import SwiftUIQuery

@Suite("KeyTuple Tests")
struct KeyTupleTests {
    @Test("KeyTuple2 with QueryOptions")
    func keyTuple2QueryOptions() async {
        let key = KeyTuple2("users", 123)

        let options = QueryOptions<String, KeyTuple2<String, Int>>(
            queryKey: key,
            queryFn: { (key: KeyTuple2<String, Int>) async throws -> String in
                "User \(key.key2)"
            }
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "users")
        #expect(options.queryKey.key2 == 123)
    }

    @Test("KeyTuple3 with QueryOptions")
    func keyTuple3QueryOptions() async {
        let key = KeyTuple3("users", 123, true)

        let options = QueryOptions<String, KeyTuple3<String, Int, Bool>>(
            queryKey: key,
            queryFn: { (key: KeyTuple3<String, Int, Bool>) async throws -> String in
                "User \(key.key2) active: \(key.key3)"
            }
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "users")
        #expect(options.queryKey.key2 == 123)
        #expect(options.queryKey.key3 == true)
    }

    @Test("KeyTuple4 with QueryOptions")
    func keyTuple4QueryOptions() async {
        let key = KeyTuple4("users", 123, true, "admin")

        let options = QueryOptions<String, KeyTuple4<String, Int, Bool, String>>(
            queryKey: key,
            queryFn: { (key: KeyTuple4<String, Int, Bool, String>) async throws -> String in
                "User \(key.key2) active: \(key.key3) role: \(key.key4)"
            }
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "users")
        #expect(options.queryKey.key2 == 123)
        #expect(options.queryKey.key3 == true)
        #expect(options.queryKey.key4 == "admin")
    }

    @Test("KeyTuple2 with Type as first key")
    func keyTuple2WithType() async {
        struct User: Codable, Sendable {
            let id: Int
            let name: String
        }

        let key = KeyTuple2(User.self, 123)

        #expect(key.key1 == "User")
        #expect(key.key2 == 123)

        let options = QueryOptions<User, KeyTuple2<String, Int>>(
            queryKey: key,
            queryFn: { (key: KeyTuple2<String, Int>) async throws -> User in
                User(id: key.key2, name: "Test User")
            }
        )

        #expect(options.queryKey == key)
    }

    @Test("KeyTuple3 with Type as first key")
    func keyTuple3WithType() async {
        struct Post: Codable, Sendable {
            let id: Int
            let title: String
        }

        let key = KeyTuple3(Post.self, 456, "published")

        #expect(key.key1 == "Post")
        #expect(key.key2 == 456)
        #expect(key.key3 == "published")

        let options = QueryOptions<Post, KeyTuple3<String, Int, String>>(
            queryKey: key,
            queryFn: { (key: KeyTuple3<String, Int, String>) async throws -> Post in
                Post(id: key.key2, title: "Post \(key.key3)")
            }
        )

        #expect(options.queryKey == key)
    }

    @Test("KeyTuple4 with Type as first key")
    func keyTuple4WithType() async {
        struct Comment: Codable, Sendable {
            let id: Int
            let text: String
        }

        let key = KeyTuple4(Comment.self, 789, "user123", true)

        #expect(key.key1 == "Comment")
        #expect(key.key2 == 789)
        #expect(key.key3 == "user123")
        #expect(key.key4 == true)

        let options = QueryOptions<Comment, KeyTuple4<String, Int, String, Bool>>(
            queryKey: key,
            queryFn: { (key: KeyTuple4<String, Int, String, Bool>) async throws -> Comment in
                Comment(id: key.key2, text: "Comment from \(key.key3)")
            }
        )

        #expect(options.queryKey == key)
    }

    @Test("KeyTuple queryHash uniqueness")
    func keyTupleQueryHash() {
        let key1 = KeyTuple2("users", 123)
        let key2 = KeyTuple2("users", 456)
        let key3 = KeyTuple2("posts", 123)

        #expect(key1.queryHash != key2.queryHash)
        #expect(key1.queryHash != key3.queryHash)
        #expect(key2.queryHash != key3.queryHash)

        let key4 = KeyTuple3("users", 123, true)
        let key5 = KeyTuple3("users", 123, false)

        #expect(key4.queryHash != key5.queryHash)

        let key6 = KeyTuple4("comments", 1, "user", true)
        let key7 = KeyTuple4("comments", 1, "admin", true)

        #expect(key6.queryHash != key7.queryHash)
    }

    @Test("KeyTuple equality")
    func keyTupleEquality() {
        let key1 = KeyTuple2("users", 123)
        let key2 = KeyTuple2("users", 123)
        let key3 = KeyTuple2("users", 456)

        #expect(key1 == key2)
        #expect(key1 != key3)

        let key4 = KeyTuple3("posts", 1, true)
        let key5 = KeyTuple3("posts", 1, true)
        let key6 = KeyTuple3("posts", 1, false)

        #expect(key4 == key5)
        #expect(key4 != key6)

        let key7 = KeyTuple4("comments", 1, "a", true)
        let key8 = KeyTuple4("comments", 1, "a", true)
        let key9 = KeyTuple4("comments", 1, "b", true)

        #expect(key7 == key8)
        #expect(key7 != key9)
    }

    // MARK: - InfiniteQueryOptions KeyTuple Tests

    @Test("InfiniteQueryOptions with KeyTuple2")
    func infiniteQueryOptionsKeyTuple2() async {
        struct Post: Sendable, Codable {
            let id: Int
            let title: String
        }

        let key = KeyTuple2("posts", 10)

        let options = InfiniteQueryOptions<[Post], QueryError, KeyTuple2<String, Int>, Int>(
            queryKey: key,
            queryFn: { (_: KeyTuple2<String, Int>, pageParam: Int?) async throws -> [Post] in
                let page = pageParam ?? 0
                return [Post(id: page, title: "Post \(page)")]
            },
            getNextPageParam: { pages, _ in
                pages.count < 3 ? pages.count : nil
            },
            initialPageParam: 0
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "posts")
        #expect(options.queryKey.key2 == 10)
    }

    @Test("KeyTuple5 with QueryOptions")
    func keyTuple5QueryOptions() async {
        let key = KeyTuple5("users", 123, true, "admin", 5.0)

        let options = QueryOptions<String, KeyTuple5<String, Int, Bool, String, Double>>(
            queryKey: key,
            queryFn: { (key: KeyTuple5<String, Int, Bool, String, Double>) async throws -> String in
                "User \(key.key2) active: \(key.key3) role: \(key.key4) score: \(key.key5)"
            }
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "users")
        #expect(options.queryKey.key2 == 123)
        #expect(options.queryKey.key3 == true)
        #expect(options.queryKey.key4 == "admin")
        #expect(options.queryKey.key5 == 5.0)
    }

    @Test("KeyTuple6 with QueryOptions")
    func keyTuple6QueryOptions() async {
        let key = KeyTuple6("posts", 456, "published", true, 10, "featured")

        let options = QueryOptions<String, KeyTuple6<String, Int, String, Bool, Int, String>>(
            queryKey: key,
            queryFn: { (key: KeyTuple6<String, Int, String, Bool, Int, String>) async throws -> String in
                "Post \(key.key2) status: \(key.key3) active: \(key.key4) priority: \(key.key5) type: \(key.key6)"
            }
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "posts")
        #expect(options.queryKey.key2 == 456)
        #expect(options.queryKey.key3 == "published")
        #expect(options.queryKey.key4 == true)
        #expect(options.queryKey.key5 == 10)
        #expect(options.queryKey.key6 == "featured")
    }

    @Test("KeyTuple5 with Type as first key")
    func keyTuple5WithType() async {
        struct Order: Codable, Sendable {
            let id: Int
            let status: String
        }

        let key = KeyTuple5(Order.self, 789, "pending", true, 99.99)

        #expect(key.key1 == "Order")
        #expect(key.key2 == 789)
        #expect(key.key3 == "pending")
        #expect(key.key4 == true)
        #expect(key.key5 == 99.99)

        let options = QueryOptions<Order, KeyTuple5<String, Int, String, Bool, Double>>(
            queryKey: key,
            queryFn: { (key: KeyTuple5<String, Int, String, Bool, Double>) async throws -> Order in
                Order(id: key.key2, status: key.key3)
            }
        )

        #expect(options.queryKey == key)
    }

    @Test("KeyTuple6 with Type as first key")
    func keyTuple6WithType() async {
        struct Product: Codable, Sendable {
            let id: Int
            let name: String
        }

        let key = KeyTuple6(Product.self, 101, "active", true, 4.5, "electronics")

        #expect(key.key1 == "Product")
        #expect(key.key2 == 101)
        #expect(key.key3 == "active")
        #expect(key.key4 == true)
        #expect(key.key5 == 4.5)
        #expect(key.key6 == "electronics")

        let options = QueryOptions<Product, KeyTuple6<String, Int, String, Bool, Double, String>>(
            queryKey: key,
            queryFn: { (key: KeyTuple6<String, Int, String, Bool, Double, String>) async throws -> Product in
                Product(id: key.key2, name: "Product \(key.key6)")
            }
        )

        #expect(options.queryKey == key)
    }

    @Test("KeyTuple5 and KeyTuple6 uniqueness")
    func keyTuple56Uniqueness() {
        let key5a = KeyTuple5("test", 1, true, "a", 1.0)
        let key5b = KeyTuple5("test", 1, true, "a", 2.0)
        let key5c = KeyTuple5("test", 1, true, "b", 1.0)

        #expect(key5a.queryHash != key5b.queryHash)
        #expect(key5a.queryHash != key5c.queryHash)
        #expect(key5b.queryHash != key5c.queryHash)

        let key6a = KeyTuple6("test", 1, "a", true, 1, "x")
        let key6b = KeyTuple6("test", 1, "a", true, 1, "y")
        let key6c = KeyTuple6("test", 1, "b", true, 1, "x")

        #expect(key6a.queryHash != key6b.queryHash)
        #expect(key6a.queryHash != key6c.queryHash)
        #expect(key6b.queryHash != key6c.queryHash)
    }

    @Test("KeyTuple5 and KeyTuple6 equality")
    func keyTuple56Equality() {
        let key5a = KeyTuple5("test", 1, true, "admin", 5.0)
        let key5b = KeyTuple5("test", 1, true, "admin", 5.0)
        let key5c = KeyTuple5("test", 1, true, "user", 5.0)

        #expect(key5a == key5b)
        #expect(key5a != key5c)

        let key6a = KeyTuple6("test", 1, "a", true, 1, "featured")
        let key6b = KeyTuple6("test", 1, "a", true, 1, "featured")
        let key6c = KeyTuple6("test", 1, "a", true, 1, "normal")

        #expect(key6a == key6b)
        #expect(key6a != key6c)
    }

    @Test("InfiniteQueryOptions with KeyTuple5")
    func infiniteQueryOptionsKeyTuple5() async {
        struct Item: Sendable, Codable {
            let id: Int
            let name: String
        }

        let key = KeyTuple5("items", "category1", true, 20, 4.5)

        let options = InfiniteQueryOptions<[Item], QueryError, KeyTuple5<String, String, Bool, Int, Double>, Int>(
            queryKey: key,
            queryFn: { (key: KeyTuple5<String, String, Bool, Int, Double>, pageParam: Int?) async throws -> [Item] in
                let page = pageParam ?? 0
                return [Item(id: page, name: "\(key.key2) item \(page)")]
            },
            getNextPageParam: { pages, _ in
                pages.count < 3 ? pages.count : nil
            },
            initialPageParam: 0
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "items")
        #expect(options.queryKey.key2 == "category1")
        #expect(options.queryKey.key3 == true)
        #expect(options.queryKey.key4 == 20)
        #expect(options.queryKey.key5 == 4.5)
    }

    @Test("InfiniteQueryOptions with KeyTuple6")
    func infiniteQueryOptionsKeyTuple6() async {
        struct Review: Sendable, Codable {
            let id: Int
            let rating: Int
        }

        let key = KeyTuple6("reviews", "product123", true, 5, 100, "verified")

        let options = InfiniteQueryOptions<
            [Review],
            QueryError,
            KeyTuple6<String, String, Bool, Int, Int, String>,
            Int
        >(
            queryKey: key,
            queryFn: { (key: KeyTuple6<
                String,
                String,
                Bool,
                Int,
                Int,
                String
            >, pageParam: Int?) async throws -> [Review] in
                let page = pageParam ?? 0
                return [Review(id: page, rating: key.key4)]
            },
            getNextPageParam: { pages, _ in
                pages.count < 2 ? pages.count : nil
            },
            initialPageParam: 0
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "reviews")
        #expect(options.queryKey.key2 == "product123")
        #expect(options.queryKey.key3 == true)
        #expect(options.queryKey.key4 == 5)
        #expect(options.queryKey.key5 == 100)
        #expect(options.queryKey.key6 == "verified")
    }
}
