//
//  CacheDirectoryConsumerTests.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Testing
import Foundation

import Cache

/// Pins that a ``FileSystemCache`` can be constructed with nothing imported but `Cache`.
///
/// Until ``CacheDirectory`` existed, the initialiser took a `FileSystemDirectory`, a type declared
/// in the `Files` package, so an adopter had to import `Files`, and name it in their own manifest,
/// to call it. Most of this file's value is that it compiles. It deliberately imports neither
/// `Files` nor anything else that declares or re-exports `FileSystemDirectory`, and it is not
/// `@testable`, so it sees exactly what an adopter sees. Were the initialiser to take a `Files`
/// type again, this file would stop building.
///
/// The leading-dot form is also what a 6.0.0 adopter wrote. `Files` is still loaded here, through
/// `Cache`, and without member import visibility (SE-0444) a loaded module's members are visible
/// whether or not the file imports it, which is how a 6.0.0 leading-dot call compiled at all. So
/// `FileSystemDirectory`'s cases are candidates here too, which makes this file the place an
/// ambiguity between the two initialisers would show: if the deprecated one were not marked as the
/// less preferred overload, `FileSystemCache(.caches)` would match both and this file would stop
/// compiling.
///
/// Nothing is registered for the file system client, so in a test run every cache here resolves
/// `foundation-dependencies`' test value, which accepts a write and keeps nothing. The tests
/// therefore show that construction and every operation run, not where an entry lands.
/// `CacheDirectoryTests` pins where it lands.
@Suite("CacheDirectory with nothing imported but Cache")
struct CacheDirectoryConsumerTests {

    @Test("A cache is constructed and used with every CacheDirectory case")
    func everyCaseConstructsAUsableCache() async throws {

        for directory in CacheDirectory.allCases {

            let cache = FileSystemCache<CodableTestValue>(directory, subfolder: "consumer")

            try await cache.stash(CodableTestValue(count: "1"), duration: .long)
            _ = try await cache.resource(for: "1")
            try await cache.removeResource(for: "1")
            try await cache.removeExpired()
            try await cache.reset()
        }
    }

    @Test("The leading-dot form compiles, with and without a subfolder")
    func leadingDotFormCompiles() async throws {

        let caches = FileSystemCache<CodableTestValue>(.caches, subfolder: "Cheeses")
        let support = FileSystemCache<CodableTestValue>(.applicationSupport)
        let explicit = FileSystemCache<CodableTestValue>(CacheDirectory.temporary, subfolder: nil)

        try await caches.stash(CodableTestValue(count: "1"), duration: .long)
        try await support.stash(CodableTestValue(count: "1"), duration: .long)
        try await explicit.stash(CodableTestValue(count: "1"), duration: .long)
    }
}
