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
    func sweepRemovesOnlyResourcesExpiredAsOfTheInstant() throws {

        let storage = VolatileStorage<TestValue>()
        storage.insert(resource("expired", expiringAt: now.addingTimeInterval(-1)))
        storage.insert(resource("live", expiringAt: now.addingTimeInterval(1)))

        let removed = storage.removeExpired(asOf: now)

        #expect(removed == 1)
        #expect(try storage.resource(for: "expired") == nil)
        #expect(try storage.resource(for: "live")?.item.count == "live")
    }

    /// Pins the boundary. Expiry is `expiry < now`, so a resource whose expiry is the instant
    /// itself has not expired at that instant; it has expired at any instant after it.
    @Test("A resource whose expiry is the instant itself is not yet expired")
    func resourceExpiringAtTheInstantIsKept() throws {

        let storage = VolatileStorage<TestValue>()
        storage.insert(resource("on-the-instant", expiringAt: now))

        #expect(storage.removeExpired(asOf: now) == 0)
        #expect(try storage.resource(for: "on-the-instant") != nil)
        #expect(storage.removeExpired(asOf: now.addingTimeInterval(0.001)) == 1)
    }

    @Test("A sweep of empty storage reports zero")
    func sweepOfEmptyStorageReportsZero() {
        #expect(VolatileStorage<TestValue>().removeExpired(asOf: now) == 0)
    }
}
