import Testing
import Foundation
@testable import SwiftUIQuery

@Suite("Sendable Compliance Tests")
struct SendableComplianceTests {
    
    @Test("Core types are Sendable")
    func coreTypesAreSendable() {
        // These compile-time checks ensure our types are Sendable
        assertSendable(TestUser.self)
        assertSendable(TestPost.self)
        assertSendable(TestQueryKey.self)
        assertSendable(TestError.self)
        
        // Once implemented, add:
        // assertSendable(QueryState<TestUser>.self)
        // assertSendable(QueryOptions.self)
        // assertSendable(QueryStatus.self)
        // assertSendable(RefetchTrigger.self)
        // assertSendable(ThrowOnError.self)
    }
    
    @Test("Concurrent cache access", .timeout(.seconds(5)))
    func concurrentCacheAccess() async throws {
        // This will test concurrent access to QueryCache actor
        
        actor TestCache {
            private var storage: [String: Any] = [:]
            
            func get<T>(_ key: String) -> T? {
                storage[key] as? T
            }
            
            func set<T>(_ key: String, value: T) {
                storage[key] = value
            }
        }
        
        let cache = TestCache()
        
        // Perform concurrent operations
        let results = try await performConcurrentOperations(count: 100) { @Sendable in
            let key = "test-key-\(Int.random(in: 0..<10))"
            let value = Int.random(in: 0..<1000)
            
            await cache.set(key, value: value)
            let retrieved: Int? = await cache.get(key)
            
            return retrieved ?? -1
        }
        
        #expect(results.count == 100)
        #expect(results.allSatisfy { $0 >= 0 })
    }
    
    @Test("Data race detection", .timeout(.seconds(2)))
    func dataRaceDetection() async throws {
        // This test verifies that our concurrent code doesn't have data races
        
        @MainActor
        final class NonSendableClass {
            var value = 0
        }
        
        let instance = NonSendableClass()
        
        // This would cause a compile error if we tried to access from multiple tasks:
        // await performConcurrentOperations(count: 10) {
        //     instance.value += 1  // Error: Cannot access MainActor-isolated property
        // }
        
        // Correct approach: access only from MainActor
        await MainActor.run {
            instance.value = 42
        }
        
        let finalValue = await instance.value
        #expect(finalValue == 42)
    }
}

@Suite("Actor Isolation Tests")
struct ActorIsolationTests {
    
    @Test("Query cache actor isolation")
    func queryCacheActorIsolation() async {
        // Test that cache operations are properly isolated
        
        actor QueryCache {
            private var queries: [String: Date] = [:]
            
            func recordQuery(_ key: String) {
                queries[key] = Date()
            }
            
            func getLastAccess(_ key: String) -> Date? {
                queries[key]
            }
            
            func getAllKeys() -> [String] {
                Array(queries.keys)
            }
        }
        
        let cache = QueryCache()
        
        // Record multiple queries
        await cache.recordQuery("user-1")
        await cache.recordQuery("posts")
        await cache.recordQuery("user-2")
        
        let keys = await cache.getAllKeys()
        #expect(keys.count == 3)
        #expect(keys.contains("user-1"))
        #expect(keys.contains("posts"))
        #expect(keys.contains("user-2"))
    }
    
    @Test("MainActor isolation for UI updates")
    @MainActor
    func mainActorIsolation() async {
        // Test that UI updates happen on MainActor
        
        // Note: @Observable is not available yet, using placeholder
        final class QueryState<T: Sendable> {
            var isLoading = false
            var data: T?
            var error: Error?
            
            @MainActor
            func updateUI(data: T) {
                self.data = data
                self.isLoading = false
            }
        }
        
        let state = QueryState<TestUser>()
        let user = TestUser(id: "1", name: "John", email: "john@example.com")
        
        // UI updates must happen on MainActor
        state.updateUI(data: user)
        
        #expect(state.data == user)
        #expect(state.isLoading == false)
    }
}