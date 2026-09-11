//
//  VolatileCacheTests.swift
//  cache
//
//  Created by Robert Nash on 15/06/2025.
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport

@testable import Cache

@Suite("Volatile Cache Tests")
struct VolatileCacheTests {

    @Test("Remove a stashed item")
    func testRemove() async throws {
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: "123")
        let identifier = item.id

        try await cache.stash(item, duration: .short)
        try await cache.removeResource(for: identifier)

        let resource = try await cache.resource(for: identifier)
        #expect(resource == nil)
    }

    @Test("Reset clears all cached resources")
    func testReset() async throws {
        let cache = VolatileCache<TestValue>()
        let item1 = TestValue(count: "123")
        let item2 = TestValue(count: "456")

        try await cache.stash(item1, duration: .short)
        try await cache.stash(item2, duration: .short)
        try await cache.reset()

        let resource1 = try await cache.resource(for: item1.id)
        let resource2 = try await cache.resource(for: item2.id)
        #expect(resource1 == nil)
        #expect(resource2 == nil)
    }

    @Test("Fetching a non-existent resource returns nil")
    func testResourceFetchNonExisting() async throws {
        let cache = VolatileCache<TestValue>()
        let identifier = TestValue(count: "123").id
        let resource = try await cache.resource(for: identifier)
        #expect(resource == nil)
    }
    
    @Test("Resource is not expired before custom duration")
    func testResourceIsNotExpiredBeforeCustomDuration() async throws {
        // Given: A short custom expiry (2 seconds from now)
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: "123")
        let identifier = item.id
        let expiry = Expiry.custom(Date().addingTimeInterval(2))

        try await cache.stash(item, duration: expiry)

        // Then: The resource should not be expired
        let resource = try await cache.resource(for: identifier)
        #expect(resource != nil)
    }

    @Test("Resource is expired after custom duration")
    func testResourceIsExpiredAfterCustomDuration() async throws {
        // Given: A short custom expiry (1 second from now)
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: "123")
        let identifier = item.id
        let expiry = Expiry.custom(Date().addingTimeInterval(-1))

        try await cache.stash(item, duration: expiry)

        // Then: The resource should be expired and unavailable
        let resource = try await cache.resource(for: identifier)
        #expect(resource == nil)
    }

    @Test("removeExpired() removes the expired entries, keeps the rest, and reports how many went")
    func removeExpiredRemovesOnlyExpiredEntries() async throws {
        let cache = VolatileCache<TestValue>()
        try await cache.stash(TestValue(count: "expired-a"), duration: .custom(Date().addingTimeInterval(-1)))
        try await cache.stash(TestValue(count: "expired-b"), duration: .custom(Date().addingTimeInterval(-3600)))
        try await cache.stash(TestValue(count: "live"), duration: .custom(Date().addingTimeInterval(3600)))

        let removed = try await cache.removeExpired()

        #expect(removed == 2)
        #expect(try await cache.resource(for: "live")?.count == "live")
    }

    /// A read cannot show that the sweep removed an expired entry, because a read reports `nil`
    /// for an expired entry either way. A second sweep can: an entry the first sweep only counted
    /// would be counted again.
    @Test("removeExpired() removes what it counts: a second sweep finds nothing")
    func secondSweepFindsNothing() async throws {
        let cache = VolatileCache<TestValue>()
        try await cache.stash(TestValue(count: "expired"), duration: .custom(Date().addingTimeInterval(-1)))

        #expect(try await cache.removeExpired() == 1)
        #expect(try await cache.removeExpired() == 0)
    }

    @Test("removeExpired() reports zero when nothing has expired, and keeps everything")
    func removeExpiredWithNothingExpiredReportsZero() async throws {
        let cache = VolatileCache<TestValue>()
        try await cache.stash(TestValue(count: "1"), duration: .long)
        try await cache.stash(TestValue(count: "2"), duration: .long)

        #expect(try await cache.removeExpired() == 0)
        #expect(try await cache.resource(for: "1")?.count == "1")
        #expect(try await cache.resource(for: "2")?.count == "2")
    }

    @Test("removeExpired() reports zero on an empty cache")
    func removeExpiredOnEmptyCacheReportsZero() async throws {
        #expect(try await VolatileCache<TestValue>().removeExpired() == 0)
    }
}
