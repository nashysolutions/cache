import Testing
import Foundation
import Dependencies
import DependenciesTestSupport

@testable import Cache

@Suite(
    "Cache Delete Tests",
    .dependencies { $0.date.now = Date() }
)
struct CacheDeleteTests {

    @Test("Remove a stashed item")
    func testRemove() async throws {
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: 123)
        let identifier = item.id

        try await cache.stash(item)
        try await cache.removeResource(for: identifier)

        let resource = try await cache.resource(for: identifier)
        #expect(resource == nil)
    }

    @Test("Reset clears all cached resources")
    func testReset() async throws {
        let cache = VolatileCache<TestValue>()
        let item1 = TestValue(count: 123)
        let item2 = TestValue(count: 456)

        try await cache.stash(item1)
        try await cache.stash(item2)
        try await cache.reset()

        let resource1 = try await cache.resource(for: item1.id)
        let resource2 = try await cache.resource(for: item2.id)
        #expect(resource1 == nil)
        #expect(resource2 == nil)
    }

    @Test("Fetching a non-existent resource returns nil")
    func testResourceFetchNonExisting() async throws {
        let cache = VolatileCache<TestValue>()
        let identifier = TestValue(count: 123).id
        let resource = try await cache.resource(for: identifier)
        #expect(resource == nil)
    }

    @Test("Resource is not expired before custom duration", .disabled("Not currently supporting resource expiry logic"))
    func testResourceIsNotExpiredBeforeCustomDuration() async throws {
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: 123)
        let identifier = item.id

        //let now = Date()
        //let expiry = Expiry.custom(now.addingTimeInterval(2)) // Expires in 2s

        try await cache.stash(item)

        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        let resource = try await cache.resource(for: identifier)

        #expect(resource != nil) // ✅ not expired yet
    }

    @Test("Resource is expired after custom duration", .disabled("Not currently supporting resource expiry logic"))
    func testResourceIsExpiredAfterCustomDuration() async throws {
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: 123)
        let identifier = item.id

        //let now = Date()
        //let expiry = Expiry.custom(now.addingTimeInterval(1)) // Expires in 1s

        try await cache.stash(item)

        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        let resource = try await cache.resource(for: identifier)

        #expect(resource == nil) // ✅ expired
    }
}
