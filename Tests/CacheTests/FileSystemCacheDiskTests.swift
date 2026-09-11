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

    @Test("Entries written in the unversioned layout are swept on first use, and nothing else is")
    func unversionedEntriesAreSweptOnFirstUse() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = FileManager.default
        let record = try unversionedRecordData(id: "orphan")

        // A 6.0.0 entry: the filename is a SHA-256 hex digest, with no extension.
        let digestNamed = root.appending(component: String(repeating: "a", count: 64))
        try record.write(to: digestNamed)

        // A pre-6 entry: the filename is the identifier's description, so it has no
        // recognisable shape at all. Only the file's contents identify it.
        let descriptionNamed = root.appending(component: "orphan")
        try record.write(to: descriptionNamed)

        // Files the cache never wrote. The second is JSON carrying both of the record's
        // keys plus one more, so it is only spared by an exact-shape check.
        let plainText = root.appending(component: "notes.txt")
        try Data("hello".utf8).write(to: plainText)
        let similarJSON = root.appending(component: "looks-similar.json")
        try Data(#"{"item":1,"expiry":1,"extra":2}"#.utf8).write(to: similarJSON)

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "42"), duration: .long)

        #expect(manager.fileExists(atPath: digestNamed.path) == false)
        #expect(manager.fileExists(atPath: descriptionNamed.path) == false)
        #expect(manager.fileExists(atPath: plainText.path))
        #expect(manager.fileExists(atPath: similarJSON.path))

        // The sweep must not have taken the entry written moments earlier with it.
        let retrieved = try await cache.resource(for: "42")
        #expect(retrieved?.count == "42")
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

/// Bytes matching what 6.0.0 and earlier wrote for one entry: the resource encoded with a
/// default `JSONEncoder`, which is what the `Files` package uses.
private func unversionedRecordData(id: String) throws -> Data {
    let resource = CodableResource(
        item: CodableTestValue(count: id),
        expiry: Date(timeIntervalSince1970: 1_700_000_000)
    )
    return try JSONEncoder().encode(resource)
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
