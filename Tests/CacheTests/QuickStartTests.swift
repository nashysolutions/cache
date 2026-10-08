//
//  QuickStartTests.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import FoundationDependencies
import Files

import Cache

/// The model <doc:QuickStart> declares, copied from the article.
///
/// Compiling it here is itself a check: the article's `Cheese` was declared `Identifiable,
/// Sendable` and then used as `FileSystemCache<Cheese>`, which does not compile because the
/// file-system cache requires `Codable`.
struct Cheese: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
}

/// Pins what <doc:QuickStart> tells a consumer, against what the package actually does.
///
/// The article is the only place this package explains how to make a ``FileSystemCache`` work, and
/// until now nothing executed a line of it. Every claim it makes about behaviour is asserted here,
/// so a change that falsifies the article fails a test rather than quietly misleading a reader.
///
/// These tests deliberately use a plain `import Cache` rather than `@testable`, because the article
/// promises a consumer something about the public surface and nothing about the internals.
///
/// The clock is pinned test by test rather than for the whole suite. Inside a test run, a cache
/// that is not given a time records an issue, as the article warns, and one test below exists to
/// show that. The tests in the live and preview contexts leave the clock alone, because there the
/// default is the real clock, as it is in a shipping app.
@Suite("QuickStart article")
struct QuickStartTests {

    /// The `VolatileCache` snippet, run.
    @Test("The VolatileCache snippet sets and retrieves", .dependency(\.date.now, pinnedNow))
    func volatileCacheSnippetRoundTrips() async throws {

        let cache = VolatileCache<Cheese>()

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

        let brie = try await cache.item(for: 1)

        #expect(brie?.name == "Brie")
    }

    /// The "Choosing an expiry" snippet, run, with the article's claim that `.after` counts its
    /// duration from the moment the item is set, and that a fixed deadline does not move with it.
    @Test(
        "The expiry snippet serves a ten-minute entry for ten minutes; an absolute one does not move",
        .dependency(\.date.now, pinnedNow)
    )
    func expirySnippetCountsFromTheMomentOfSetting() async throws {

        let cache = VolatileCache<Cheese>()
        let deadline = pinnedNow.addingTimeInterval(5 * 60)

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .after(.seconds(10 * 60)))
        try await withDependencies {
            $0.date.now = pinnedNow.addingTimeInterval(60)
        } operation: {
            try await cache.setItem(Cheese(id: 2, name: "Cheddar"), expiry: .at(deadline))
        }

        func lookUp(_ id: Int, secondsAfterPinnedNow offset: TimeInterval) async throws -> Cheese? {
            try await withDependencies {
                $0.date.now = pinnedNow.addingTimeInterval(offset)
            } operation: {
                try await cache.item(for: id)
            }
        }

        #expect(try await lookUp(1, secondsAfterPinnedNow: 10 * 60)?.name == "Brie")
        #expect(try await lookUp(1, secondsAfterPinnedNow: 10 * 60 + 1) == nil)
        #expect(try await lookUp(2, secondsAfterPinnedNow: 5 * 60)?.name == "Cheddar")
        #expect(try await lookUp(2, secondsAfterPinnedNow: 5 * 60 + 1) == nil)
    }

    /// The guard for the whole change: a cache built exactly the way the article says to build
    /// one, with nothing registered, writes to the real file system.
    ///
    /// Before `FileSystemResourceClientKey` had a live value, this is the case that silently did
    /// nothing: a write reported success and no bytes reached disk. The defect was silence, so
    /// this test asserts the presence of a file rather than the absence of an error, which a
    /// no-op passes just as readily.
    ///
    /// `$0.context = .live` is not the boilerplate this change removed. It says "behave as a
    /// shipping app does", because `swift-dependencies` resolves a dependency's test value inside
    /// a test run whatever else is true. Nothing is registered for `fileSystemResourceClient`
    /// here, which is the point.
    ///
    /// The article nominates `.caches`; this test nominates `.temporary` so that a test run does
    /// not leave anything in a real caches directory. Everything else is the article's own code.
    @Test("A cache built the way the article says writes to disk with nothing registered")
    func fileSystemCacheSnippetWritesToDiskWithNothingRegistered() async throws {

        let subfolder = "cache-quickstart-tests-\(UUID().uuidString)"
        let root = FileManager.default.temporaryDirectory
            .appending(component: subfolder, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = withDependencies {
            $0.context = .live
        } operation: {
            FileSystemCache<Cheese>(.temporary, subfolder: subfolder)
        }

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

        #expect(regularFiles(under: root).count == 1)

        let brie = try await cache.item(for: 1)

        #expect(brie?.name == "Brie")
    }

    /// Pins the article's statement that a cache directory which cannot be created is reported as
    /// an error rather than absorbed.
    ///
    /// The fault is staged by putting an ordinary file where the cache expects to create its
    /// folder, so `FileManager` cannot create it. Both a write and a read are asserted, because
    /// the reporting rule is asymmetric: a read reports a miss and an unservable entry as `nil`,
    /// and only a genuine fault as an error, so a read is the one that could plausibly have
    /// laundered this into a miss.
    @Test("A cache directory that cannot be created is reported as an error, not absorbed")
    func liveClientReportsADirectoryItCannotCreate() async throws {

        let subfolder = "cache-quickstart-tests-\(UUID().uuidString)"
        let blocker = FileManager.default.temporaryDirectory.appending(component: subfolder)
        try Data("an ordinary file where the cache wants a folder".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }

        let cache = withDependencies {
            $0.context = .live
        } operation: {
            FileSystemCache<Cheese>(.temporary, subfolder: subfolder)
        }

        await #expect(throws: (any Error).self) {
            try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)
        }

        await #expect(throws: (any Error).self) {
            _ = try await cache.item(for: 1)
        }
    }

    /// Pins the warning the article gives about a test context, one of the two places the
    /// original trap survives its own fix.
    ///
    /// `swift-dependencies` resolves `testValue` inside a test whether or not a live value exists,
    /// and `foundation-dependencies` declares that test value as a mock which accepts a write and
    /// keeps nothing. So a consumer's integration test that registers no client still gets a cache
    /// that reports every write as a success and then serves nothing, with no warning at all.
    ///
    /// This package cannot close that from here: `testValue` is declared in
    /// `foundation-dependencies` and there can only be one declaration of it.
    ///
    /// A failure here is good news rather than a regression. It means the mock has been replaced
    /// with something that either keeps what it is given or fails loudly, and the article's
    /// warning has become false and needs deleting.
    ///
    /// The clock is pinned so that the only thing left unregistered is the file system client,
    /// which is what this test is about.
    @Test(
        "In a test context with nothing registered, the cache keeps nothing and says so nowhere",
        .dependency(\.date.now, pinnedNow)
    )
    func fileSystemCacheKeepsNothingInATestContext() async throws {

        let subfolder = "cache-quickstart-tests-\(UUID().uuidString)"
        let root = FileManager.default.temporaryDirectory
            .appending(component: subfolder, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = FileSystemCache<Cheese>(.temporary, subfolder: subfolder)

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

        #expect(try await cache.item(for: 1) == nil)
        #expect(FileManager.default.fileExists(atPath: root.path) == false)
    }

    /// The second place, and the one that matters more, because nobody opts into it.
    ///
    /// A preview resolves `previewValue`. `DependencyKey` supplies a default returning
    /// `liveValue`, so declaring a live value looks like it should be enough, and it is not: the
    /// witness is already bound by `TestDependencyKey`'s own default, which returns `testValue`,
    /// at the conformance site in `foundation-dependencies`. `swift-dependencies` states the rule
    /// on `DependencyKey`: a `previewValue` must be supplied in the same module as the
    /// `TestDependencyKey` conformance.
    ///
    /// So a developer building UI in a preview canvas, who has opted into no harness at all, gets
    /// a cache that appears to work and serves nothing. The article warns about it; this is what
    /// makes the warning checkable.
    ///
    /// As above, a failure here means the situation improved upstream and the article is now
    /// wrong, not that this package regressed.
    @Test("In a preview with nothing registered, the cache keeps nothing either")
    func fileSystemCacheKeepsNothingInAPreview() async throws {

        let subfolder = "cache-quickstart-tests-\(UUID().uuidString)"
        let root = FileManager.default.temporaryDirectory
            .appending(component: subfolder, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = withDependencies {
            $0.context = .preview
        } operation: {
            FileSystemCache<Cheese>(.temporary, subfolder: subfolder)
        }

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

        #expect(try await cache.item(for: 1) == nil)
        #expect(FileManager.default.fileExists(atPath: root.path) == false)
    }

    /// The `removeExpired()` snippet, run, with the article's claim that nothing calls it for you.
    ///
    /// A write and a read of another identifier happen between setting an expired item and the
    /// sweep. If either had swept on the consumer's behalf, the count would be zero.
    @Test(
        "The removeExpired() snippet sweeps only when called: a write and a read before it remove nothing",
        .dependency(\.date.now, pinnedNow)
    )
    func removeExpiredSnippetSweepsOnlyWhenCalled() async throws {

        let cache = VolatileCache<Cheese>()

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .at(pinnedNow.addingTimeInterval(-60)))
        try await cache.setItem(Cheese(id: 2, name: "Cheddar"), expiry: .long)
        _ = try await cache.item(for: 2)

        let removed = try await cache.removeExpired()

        #expect(removed == 1)
        #expect(try await cache.item(for: 2)?.name == "Cheddar")

        // "The result can be ignored." This compiles without an assignment, which is the claim.
        try await cache.removeExpired()
    }

    /// The same snippet against the file-backed cache the article promises it for as well, in the
    /// live context, so that what is swept is a file on disk.
    @Test("The removeExpired() snippet removes an expired entry from disk")
    func removeExpiredSnippetRemovesAnEntryFromDisk() async throws {

        let subfolder = "cache-quickstart-tests-\(UUID().uuidString)"
        let root = FileManager.default.temporaryDirectory
            .appending(component: subfolder, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = withDependencies {
            $0.context = .live
        } operation: {
            FileSystemCache<Cheese>(.temporary, subfolder: subfolder)
        }

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .at(Date().addingTimeInterval(-60)))
        try await cache.setItem(Cheese(id: 2, name: "Cheddar"), expiry: .long)
        #expect(regularFiles(under: root).count == 2)

        let removed = try await cache.removeExpired()

        #expect(removed == 1)
        #expect(regularFiles(under: root).count == 1)
        #expect(try await cache.item(for: 2)?.name == "Cheddar")
    }

    /// The "Controlling time" snippet, run as written.
    ///
    /// The article states two rules, and the second lookup depends on both. The item is set outside
    /// any scope, so its hour is counted from `storedAt` only if the cache kept the time it was
    /// constructed with. Each lookup runs in a scope of its own, so it sees the entry as 59 or 61
    /// minutes old only if the scope around a call takes precedence over the construction scope.
    /// Were either rule false, `gone` would be the cheese.
    @Test("The time snippet serves an hour's entry at 59 minutes and not at 61, without waiting")
    func timeSnippetServesAtFiftyNineMinutesAndNotAtSixtyOne() async throws {

        let storedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let cache = withDependencies {
            $0.date.now = storedAt
        } operation: {
            VolatileCache<Cheese>()
        }

        try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

        let brie = try await withDependencies {
            $0.date.now = storedAt.addingTimeInterval(59 * 60)
        } operation: {
            try await cache.item(for: 1)
        }

        let gone = try await withDependencies {
            $0.date.now = storedAt.addingTimeInterval(61 * 60)
        } operation: {
            try await cache.item(for: 1)
        }

        #expect(brie?.name == "Brie")
        #expect(gone == nil)
    }

    /// Pins the article's warning that a test must supply the time.
    ///
    /// `swift-dependencies` declares no test value for `\.date`, so a cache that is not given a
    /// time reads the real clock and records an issue. This package cannot declare one either,
    /// because the key is private to `swift-dependencies`.
    ///
    /// A failure here means the issue is no longer recorded. The article's warning is then false,
    /// and the pinning in every other suite is no longer what keeps them passing.
    @Test("In a test context, a cache that is not given a time records an issue")
    func cacheWithoutATimeRecordsAnIssueInATestContext() async throws {

        let cache = VolatileCache<Cheese>()

        try await withKnownIssue {
            try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)
        } matching: { issue in
            issue.comments.contains { $0.rawValue.contains(#"@Dependency(\.date) has no test implementation"#) }
        }
    }
}
