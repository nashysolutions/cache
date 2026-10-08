//
//  DeprecatedAPITests.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport

import Cache

/// Pins that code written against 6.0.0 still compiles and behaves as it did.
///
/// 6.0.0 made `Resource` and `CodableResource` public, and its `Cache` protocol had no
/// `removeExpired()` requirement. Each test below is written the way a 6.0.0 consumer wrote it,
/// so much of the suite's value is that it compiles. Were a shim removed, or its shape changed,
/// this file would stop building.
///
/// The import is deliberately not `@testable`: a consumer sees only the public surface, and the
/// package's own internal types must not stand in for the shims here.
///
/// The build reports a deprecation warning for each use of a shim below. Those are the warnings a
/// 6.0.0 consumer sees, and they are expected. They cannot be silenced by marking this suite
/// deprecated, because Swift Testing refuses a suite or test that is. They go when the shims and
/// this file are removed in 8.0.0.
@Suite("Deprecated 6.0.0 API")
struct DeprecatedAPITests {

    @Test("A Resource is built and read the way 6.0.0 code did")
    func resourceIsBuiltAndRead() async {

        let expiry = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let resource = Resource(item: TestValue(count: "1"), expiry: expiry)

        // Resource was Sendable in 6.0.0, so it can still cross into a detached task.
        let item = await Task.detached { resource.item }.value

        #expect(item == TestValue(count: "1"))
        #expect(resource.expiry == expiry)
    }

    @Test("Resources compare and hash by the item's identifier alone, as in 6.0.0")
    func resourceEqualityIsByIdentifier() {

        let older = Resource(
            item: TestDocument(id: "key", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )
        let newer = Resource(
            item: TestDocument(id: "key", body: "newer"),
            expiry: Date(timeIntervalSinceReferenceDate: 2_000_000)
        )
        let other = Resource(
            item: TestDocument(id: "other", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        #expect(older == newer)
        #expect(older != other)
        #expect(Set([older, newer, other]).count == 2)
    }

    @Test("A CodableResource round-trips through JSON with the keys 6.0.0 wrote")
    func codableResourceRoundTrips() throws {

        let resource = CodableResource(
            item: TestDocument(id: "key", body: "body"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(CodableResource<TestDocument>.self, from: data)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(decoded.item == resource.item)
        #expect(decoded.expiry == resource.expiry)
        #expect(Set(object.keys) == ["item", "expiry"])
    }

    @Test("CodableResources compare and hash by the item's identifier alone, as in 6.0.0")
    func codableResourceEqualityIsByIdentifier() {

        let older = CodableResource(
            item: TestDocument(id: "key", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )
        let newer = CodableResource(
            item: TestDocument(id: "key", body: "newer"),
            expiry: Date(timeIntervalSinceReferenceDate: 2_000_000)
        )
        let other = CodableResource(
            item: TestDocument(id: "other", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        #expect(older == newer)
        #expect(older != other)
        #expect(Set([older, newer, other]).count == 2)
    }

    /// The default must not report a sweep that never ran. Returning `0` would tell the caller
    /// that nothing had expired, when nothing had been looked at.
    @Test("A 6.0.0 conformance without removeExpired() throws featureUnsupported when swept")
    func defaultRemoveExpiredThrowsUnsupported() async {

        let error = await #expect(throws: CocoaError.self) {
            try await sweep(SixPointZeroCache())
        }

        #expect(error?.code == .featureUnsupported)
    }

    /// The default is reached only by a conformance that has no sweep. Both caches in the package
    /// have one, and generic code over `Cache` must reach it, not the default.
    @Test("Generic code sweeping a package cache reaches its own sweep, not the default", .dependency(\.date.now, pinnedNow))
    func packageCacheDoesNotUseTheDefault() async throws {

        let cache = VolatileCache<TestValue>()
        try await cache.stash(TestValue(count: "expired"), duration: .custom(.distantPast))

        #expect(try await sweep(cache) == 1)
    }
}

/// Sweeps any cache the way generic consumer code does, through the protocol requirement.
private func sweep<C: Cache>(_ cache: C) async throws -> Int {
    try await cache.removeExpired()
}

/// A conformance written against 6.0.0, whose `Cache` protocol had no `removeExpired()`.
///
/// It implements every requirement 6.0.0 had and nothing more, so it compiles only because of the
/// default.
private struct SixPointZeroCache: Cache {

    func stash(_ item: TestValue, duration: Expiry) async throws {}

    func removeResource(for identifier: TestValue.ID) async throws {}

    func resource(for identifier: TestValue.ID) async throws -> TestValue? { nil }

    func reset() async throws {}
}
