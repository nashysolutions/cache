//
//  CacheProtocolSendabilityTests.swift
//  cache
//
//  Created by Robert Nash on 05/10/2026.
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport

import Cache

/// Pins the `Sendable` bounds that ``Cache`` places on its item and the item's identifier.
///
/// Both conformers already required them, but the protocol did not state them, and generic code
/// can rely only on what the protocol states. Without them, generic code over `Cache` could not
/// call the cache from an actor at all.
///
/// The guard is that this file compiles: the helper below stops building if either bound is
/// removed from `Cache.Item`. The test runs it only so that the round trip is also seen to work.
///
/// These tests deliberately use a plain `import Cache` rather than `@testable`, because the bounds
/// are a promise to a consumer, who sees only the public surface.
@Suite("Cache protocol sendability", .dependency(\.date.now, pinnedNow))
struct CacheProtocolSendabilityTests {

    @Test("Generic code on the main actor can set an item and read it back by identifier")
    func mainActorGenericCodeRoundTrips() async throws {

        let read = try await setAndRead(TestValue(count: "1"), by: "1", in: VolatileCache<TestValue>())

        #expect(read?.count == "1")
    }
}

/// Sets an item, then reads it back by an identifier the caller already holds.
///
/// Every requirement of ``Cache`` is asynchronous and nonisolated, so each call here leaves the
/// main actor. Sending `item` to ``Cache/setItem(_:expiry:)`` needs `Item: Sendable`.
///
/// Sending `identifier` needs `Item.ID: Sendable` as well, because a parameter of a main-actor
/// function belongs to the main actor's isolation. An identifier read from the item at the call
/// site would not need that bound, which is why the identifier is a parameter here: a caller that
/// holds an identifier and wants the item back is the ordinary case.
@MainActor
private func setAndRead<C: Cache>(_ item: C.Item, by identifier: C.Item.ID, in cache: C) async throws -> C.Item? {
    try await cache.setItem(item, expiry: .short)
    return try await cache.item(for: identifier)
}
