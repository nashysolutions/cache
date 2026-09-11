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
@Suite("QuickStart article")
struct QuickStartTests {

    /// The `VolatileCache` snippet, run.
    @Test("The VolatileCache snippet stashes and retrieves")
    func volatileCacheSnippetRoundTrips() async throws {

        let cache = VolatileCache<Cheese>()

        try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)

        let brie = try await cache.resource(for: 1)

        #expect(brie?.name == "Brie")
    }

    /// The guard for the whole change: a cache built exactly the way the article says to build
    /// one, with nothing registered, writes to the real file system.
    ///
    /// Before `FileSystemResourceClientKey` had a live value, this is the case that silently did
    /// nothing: `stash` reported success and no bytes reached disk. The defect was silence, so
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

        try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)

        #expect(regularFiles(under: root).count == 1)

        let brie = try await cache.resource(for: 1)

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
            try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)
        }

        await #expect(throws: (any Error).self) {
            _ = try await cache.resource(for: 1)
        }
    }

    /// Pins the warning the article gives about a test context, one of the two places the
    /// original trap survives its own fix.
    ///
    /// `swift-dependencies` resolves `testValue` inside a test whether or not a live value exists,
    /// and `foundation-dependencies` declares that test value as a mock which accepts a write and
    /// keeps nothing. So a consumer's integration test that registers no client still gets a cache
    /// that reports every stash as a success and then serves nothing, with no warning at all.
    ///
    /// This package cannot close that from here: `testValue` is declared in
    /// `foundation-dependencies` and there can only be one declaration of it.
    ///
    /// A failure here is good news rather than a regression. It means the mock has been replaced
    /// with something that either keeps what it is given or fails loudly, and the article's
    /// warning has become false and needs deleting.
    @Test("In a test context with nothing registered, the cache keeps nothing and says so nowhere")
    func fileSystemCacheKeepsNothingInATestContext() async throws {

        let subfolder = "cache-quickstart-tests-\(UUID().uuidString)"
        let root = FileManager.default.temporaryDirectory
            .appending(component: subfolder, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = FileSystemCache<Cheese>(.temporary, subfolder: subfolder)

        try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)

        #expect(try await cache.resource(for: 1) == nil)
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

        try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)

        #expect(try await cache.resource(for: 1) == nil)
        #expect(FileManager.default.fileExists(atPath: root.path) == false)
    }
}
