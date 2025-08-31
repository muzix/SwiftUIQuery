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
                return "User \(key.key2)"
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
                return "User \(key.key2) active: \(key.key3)"
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
                return "User \(key.key2) active: \(key.key3) role: \(key.key4)"
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
                return User(id: key.key2, name: "Test User")
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
                return Post(id: key.key2, title: "Post \(key.key3)")
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
                return Comment(id: key.key2, text: "Comment from \(key.key3)")
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
            getNextPageParam: { pages in
                return pages.count < 3 ? pages.count : nil
            },
            initialPageParam: 0
        )

        #expect(options.queryKey == key)
        #expect(options.queryKey.key1 == "posts")
        #expect(options.queryKey.key2 == 10)
    }
}
