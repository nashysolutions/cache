//
//  VolatileStorageTests.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Testing
import Foundation

@testable import Cache

/// Exercises the in-memory sweep at the storage layer, where the instant is a parameter.
///
/// The cache-level tests can only stash entries that are already expired and count what the sweep
/// reports. Here the moment is chosen outright, nothing reads the wall clock, and the storage's own
/// lookup, which does not filter by expiry, shows what is actually left.
@Suite("VolatileStorage expired-entry sweep")
struct VolatileStorageTests {

    /// The instant every test below judges against.
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func resource(_ count: String, expiringAt expiry: Date) -> Resource<TestValue> {
        Resource(item: TestValue(count: count), expiry: expiry)
    }

    @Test("Resources whose expiry precedes the instant are removed; the rest are kept")
    func sweepRemovesOnlyResourcesExpiredAsOfTheInstant() {

        let storage = VolatileStorage<TestValue>()
        storage.insert(resource("expired", expiringAt: now.addingTimeInterval(-1)))
        storage.insert(resource("live", expiringAt: now.addingTimeInterval(1)))

        let removed = storage.removeExpired(asOf: now)

        #expect(removed == 1)
        #expect(storage.resource(for: "expired") == nil)
        #expect(storage.resource(for: "live")?.item.count == "live")
    }

    /// Pins the boundary. Expiry is `expiry < now`, so a resource whose expiry is the instant
    /// itself has not expired at that instant; it has expired at any instant after it.
    @Test("A resource whose expiry is the instant itself is not yet expired")
    func resourceExpiringAtTheInstantIsKept() {

        let storage = VolatileStorage<TestValue>()
        storage.insert(resource("on-the-instant", expiringAt: now))

        #expect(storage.removeExpired(asOf: now) == 0)
        #expect(storage.resource(for: "on-the-instant") != nil)
        #expect(storage.removeExpired(asOf: now.addingTimeInterval(0.001)) == 1)
    }

    @Test("A sweep of empty storage reports zero")
    func sweepOfEmptyStorageReportsZero() {
        #expect(VolatileStorage<TestValue>().removeExpired(asOf: now) == 0)
    }
}

/// Pins that the in-memory store holds one entry per identifier.
///
/// A second insert under an identifier the store already holds must replace that entry, neither
/// sitting beside it nor being ignored in its favour.
@Suite("VolatileStorage insertion")
struct VolatileStorageInsertionTests {

    @Test("Storing twice under one identifier keeps one entry and serves the newer value")
    func insertUnderAHeldIdentifierReplacesTheEntry() {

        let storage = VolatileStorage<KeyedValue>()
        let olderExpiry = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let newerExpiry = olderExpiry.addingTimeInterval(60)

        storage.insert(Resource(item: KeyedValue(id: "key", payload: "older"), expiry: olderExpiry))
        storage.insert(Resource(item: KeyedValue(id: "key", payload: "newer"), expiry: newerExpiry))

        let held = storage.resource(for: "key")
        #expect(held?.item.payload == "newer")
        #expect(held?.expiry == newerExpiry)

        // A sweep at an instant after every expiry removes every entry, so its count is the
        // number of entries held. Storage has no other way to report it.
        #expect(storage.removeExpired(asOf: .distantFuture) == 1)
    }
}

/// An item whose identifier is independent of its payload.
///
/// ``TestValue`` derives its identifier from its only field, so it cannot hold two different values
/// under one identifier, which is the case the replacement test needs.
private struct KeyedValue: Identifiable, Sendable {

    let id: String

    let payload: String
}
