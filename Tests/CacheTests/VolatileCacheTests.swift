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

@Suite("Volatile Cache Tests", .dependency(\.date.now, pinnedNow))
struct VolatileCacheTests {

    @Test("Remove an item that was set")
    func testRemove() async throws {
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: "123")
        let identifier = item.id

        try await cache.setItem(item, expiry: .short)
        try await cache.removeItem(for: identifier)

        let resource = try await cache.item(for: identifier)
        #expect(resource == nil)
    }

    @Test("removeAll() clears all cached items")
    func testRemoveAll() async throws {
        let cache = VolatileCache<TestValue>()
        let item1 = TestValue(count: "123")
        let item2 = TestValue(count: "456")

        try await cache.setItem(item1, expiry: .short)
        try await cache.setItem(item2, expiry: .short)
        try await cache.removeAll()

        let resource1 = try await cache.item(for: item1.id)
        let resource2 = try await cache.item(for: item2.id)
        #expect(resource1 == nil)
        #expect(resource2 == nil)
    }

    @Test("Fetching a non-existent resource returns nil")
    func testResourceFetchNonExisting() async throws {
        let cache = VolatileCache<TestValue>()
        let identifier = TestValue(count: "123").id
        let resource = try await cache.item(for: identifier)
        #expect(resource == nil)
    }

    /// Pins replace semantics: setting a second item under an identifier the cache already holds
    /// replaces the first, rather than being ignored.
    ///
    /// The two documents share an identifier and differ only in their body, so the read can tell
    /// "the second item won" from "the first item was kept". ``TestValue`` cannot do this,
    /// because its identifier is its only field.
    @Test("A second item set under the same identifier replaces the first")
    func secondItemUnderSameIdentifierReplacesTheFirst() async throws {
        let cache = VolatileCache<TestDocument>()
        let first = TestDocument(id: "1", body: "first draft")
        let second = TestDocument(id: "1", body: "second draft")

        try await cache.setItem(first, expiry: .long)
        try await cache.setItem(second, expiry: .long)

        #expect(try await cache.item(for: "1") == second)
    }

    @Test("An item is served before its absolute expiry")
    func testItemIsServedBeforeItsAbsoluteExpiry() async throws {
        // Given: An absolute expiry 2 seconds after the pinned time
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: "123")
        let identifier = item.id
        let expiry = Expiry.at(pinnedNow.addingTimeInterval(2))

        try await cache.setItem(item, expiry: expiry)

        // Then: The entry should not be expired, and should be the item that was set
        let resource = try await cache.item(for: identifier)
        #expect(resource == item)
    }

    @Test("An item is not served after its absolute expiry")
    func testItemIsNotServedAfterItsAbsoluteExpiry() async throws {
        // Given: An absolute expiry 1 second before the pinned time
        let cache = VolatileCache<TestValue>()
        let item = TestValue(count: "123")
        let identifier = item.id
        let expiry = Expiry.at(pinnedNow.addingTimeInterval(-1))

        try await cache.setItem(item, expiry: expiry)

        // Then: The resource should be expired and unavailable
        let resource = try await cache.item(for: identifier)
        #expect(resource == nil)
    }

    @Test("removeExpired() removes the expired entries, keeps the rest, and reports how many went")
    func removeExpiredRemovesOnlyExpiredEntries() async throws {
        let cache = VolatileCache<TestValue>()
        try await cache.setItem(TestValue(count: "expired-a"), expiry: .at(pinnedNow.addingTimeInterval(-1)))
        try await cache.setItem(TestValue(count: "expired-b"), expiry: .at(pinnedNow.addingTimeInterval(-3600)))
        try await cache.setItem(TestValue(count: "live"), expiry: .at(pinnedNow.addingTimeInterval(3600)))

        let removed = try await cache.removeExpired()

        #expect(removed == 2)
        #expect(try await cache.item(for: "live")?.count == "live")
    }

    /// A read cannot show that the sweep removed an expired entry, because a read reports `nil`
    /// for an expired entry either way. A second sweep can: an entry the first sweep only counted
    /// would be counted again.
    @Test("removeExpired() removes what it counts: a second sweep finds nothing")
    func secondSweepFindsNothing() async throws {
        let cache = VolatileCache<TestValue>()
        try await cache.setItem(TestValue(count: "expired"), expiry: .at(pinnedNow.addingTimeInterval(-1)))

        #expect(try await cache.removeExpired() == 1)
        #expect(try await cache.removeExpired() == 0)
    }

    @Test("removeExpired() reports zero when nothing has expired, and keeps everything")
    func removeExpiredWithNothingExpiredReportsZero() async throws {
        let cache = VolatileCache<TestValue>()
        try await cache.setItem(TestValue(count: "1"), expiry: .long)
        try await cache.setItem(TestValue(count: "2"), expiry: .long)

        #expect(try await cache.removeExpired() == 0)
        #expect(try await cache.item(for: "1")?.count == "1")
        #expect(try await cache.item(for: "2")?.count == "2")
    }

    @Test("removeExpired() reports zero on an empty cache")
    func removeExpiredOnEmptyCacheReportsZero() async throws {
        #expect(try await VolatileCache<TestValue>().removeExpired() == 0)
    }
}
