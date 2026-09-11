//
//  FileSystemCacheDiskTests.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Testing
import Foundation
import CryptoKit
import Dependencies
import DependenciesTestSupport
import FoundationDependencies
import Files

@testable import Cache

/// Exercises ``FileSystemCache`` against a real file system, rooted at a throwaway directory.
///
/// These tests are deliberately layout-agnostic: they never name the folder or the file
/// extension the cache uses. They assert only what a consumer can observe: which of *their* files
/// survive, and whether the directory they nominated is still there.
@Suite("FileSystemCache on-disk behaviour")
struct FileSystemCacheDiskTests {

    @Test("reset() leaves the base directory and a foreign file intact when no subfolder is configured")
    func resetSparesBaseDirectoryAndForeignFile() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let sentinel = root.appending(component: "unrelated-user-file.txt")
        try Data("do not delete me".utf8).write(to: sentinel)

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)
        try await cache.reset()

        #expect(FileManager.default.fileExists(atPath: sentinel.path))
        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(regularFiles(under: root) == ["unrelated-user-file.txt"])
    }

    @Test("reset() leaves foreign files in the configured subfolder and the base directory intact")
    func resetSparesForeignFilesAroundConfiguredSubfolder() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let baseSentinel = root.appending(component: "unrelated-base.txt")
        try Data("do not delete me".utf8).write(to: baseSentinel)

        let shared = root.appending(component: "shared", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        let sharedSentinel = shared.appending(component: "unrelated-shared.txt")
        try Data("do not delete me either".utf8).write(to: sharedSentinel)

        let cache = makeCache(root: root, subfolder: "shared")
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)
        try await cache.reset()

        #expect(FileManager.default.fileExists(atPath: baseSentinel.path))
        #expect(FileManager.default.fileExists(atPath: sharedSentinel.path))
        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(regularFiles(under: root) == ["unrelated-base.txt", "shared/unrelated-shared.txt"])
    }

    /// The measurement that separates "delete only the files this cache wrote" from
    /// "delete the directory this cache writes into".
    ///
    /// Both survive the two tests above; only the former survives this one.
    @Test("reset() leaves a foreign file sitting alongside the cache's own entries intact")
    func resetSparesForeignFileBesideItsOwnEntries() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: "shared")
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        // Find where the cache actually writes, without asserting what that location is.
        let entry = try #require(regularFiles(under: root).first)
        let writeDirectory = root.appending(path: entry).deletingLastPathComponent()

        let sentinel = writeDirectory.appending(component: "unrelated-neighbour.txt")
        try Data("do not delete me".utf8).write(to: sentinel)

        try await cache.reset()

        #expect(FileManager.default.fileExists(atPath: sentinel.path))
        #expect(regularFiles(under: root).count == 1)
    }

    /// Pins the path documented in <doc:OnDiskFormat>, spelled out here rather than read back from
    /// the source constants. Changing the layout without also changing the article, or without
    /// moving to a new version folder, fails here.
    @Test("An entry is written to the documented path")
    func entryIsWrittenToTheDocumentedPath() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: "shared")
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let digest = SHA256.hash(data: Data("1".utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        #expect(regularFiles(under: root) == ["shared/cache-v2/\(digest).cache"])
    }

    /// A file the consumer wrote must survive the cache being used, even when its contents happen
    /// to have the same shape as a cache entry.
    ///
    /// Both fixtures below are ordinary application data: a shopping list, and a session token
    /// with an expiry. Each is a JSON object whose keys are exactly `item` and `expiry` with a
    /// numeric `expiry`, which is also the shape of a cache entry. Shape is not provenance.
    /// Nothing about either file says this package wrote it, and any TTL wrapper writes the same
    /// shape, so neither may be touched. This is a fresh directory with no earlier install, so
    /// there is nothing here to clean up in the first place.
    ///
    /// A first-use sweep that identified its candidates by content shape deleted both on the
    /// first `stash()`, silently, with no error and no opt-out. That sweep has been taken out,
    /// and this test is what stops it, or anything like it, coming back.
    @Test("A consumer's own JSON file shaped like a cache entry survives the cache being used")
    func consumerFilesShapedLikeCacheEntriesSurviveFirstUse() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = FileManager.default

        // Sits directly in the base directory, which is the whole scope of a `subfolder: nil`
        // cache. On `.documents` that scope is the app's entire Documents directory.
        let shoppingList = root.appending(component: "shopping-list.json")
        let shoppingListBody = Data(#"{"item":"milk","expiry":3}"#.utf8)
        try shoppingListBody.write(to: shoppingList)

        // Sits in the subfolder a second cache is scoped to. Key order is reversed and `item` is
        // an object rather than a string, to show that neither is what would make a file foreign.
        let shared = root.appending(component: "shared", directoryHint: .isDirectory)
        try manager.createDirectory(at: shared, withIntermediateDirectories: true)
        let session = shared.appending(component: "session.json")
        let sessionBody = Data(#"{"expiry":1893456000,"item":{"token":"abc"}}"#.utf8)
        try sessionBody.write(to: session)

        let baseCache = makeCache(root: root, subfolder: nil)
        try await baseCache.stash(CodableTestValue(count: "1"), duration: .long)

        let subfolderCache = makeCache(root: root, subfolder: "shared")
        try await subfolderCache.stash(CodableTestValue(count: "2"), duration: .long)

        #expect(manager.fileExists(atPath: shoppingList.path))
        #expect(manager.fileExists(atPath: session.path))
        #expect((try? Data(contentsOf: shoppingList)) == shoppingListBody)
        #expect((try? Data(contentsOf: session)) == sessionBody)
    }

    /// Entries written before the versioned layout existed are orphaned, not cleaned up.
    ///
    /// This is the cost of the guard above: there is no property of such an entry that separates
    /// it from a file the consumer wrote, so the package leaves it alone and leaks the disk. See
    /// ``FileSystemLayout`` for why that trade is the right way round.
    @Test("An entry from a layout before cache-v2 is left on disk, not cleaned up")
    func entriesFromAnEarlierLayoutAreLeftOnDisk() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        // A 6.0.0 entry: the filename is a SHA-256 hex digest, with no extension, and the body
        // is exactly what this package wrote back then.
        let orphan = root.appending(component: String(repeating: "a", count: 64))
        let body = try JSONEncoder().encode(
            CodableResource(
                item: CodableTestValue(count: "orphan"),
                expiry: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        try body.write(to: orphan)

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "42"), duration: .long)
        try await cache.reset()

        #expect(FileManager.default.fileExists(atPath: orphan.path))
        #expect((try? Data(contentsOf: orphan)) == body)
    }
}

// MARK: - Fixtures

private func makeSandbox() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(component: "cache-disk-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .standardizedFileURL
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeCache(root: URL, subfolder: String?) -> FileSystemCache<CodableTestValue> {
    let agent = SandboxAgent(root: root)
    return withDependencies {
        $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
            try FileSystemFolderStore(agent: agent, kind: directory, subfolder: folder)
        }
    } operation: {
        FileSystemCache(.documents, subfolder: subfolder)
    }
}

/// Every regular file beneath `root`, as paths relative to it. Directories are excluded, so an
/// empty folder the cache created is invisible here.
private func regularFiles(under root: URL) -> Set<String> {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey]
    ) else {
        return []
    }

    let prefix = root.path + "/"
    var paths: Set<String> = []

    for case let url as URL in enumerator {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else { continue }
        let path = url.standardizedFileURL.path
        paths.insert(path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path)
    }

    return paths
}
