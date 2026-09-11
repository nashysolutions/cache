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

/// Exercises what ``FileSystemCache`` does when there is nothing to serve, against a real file
/// system.
///
/// The distinction these tests pin is between an identifier the cache holds nothing for, which is
/// ordinary and reports `nil`, and a lookup that could not be completed, which is a fault and
/// throws. An entry whose stored payload no longer decodes sits with the first group: it can
/// never be served, so it reports `nil` and is cleared rather than left on disk.
@Suite("FileSystemCache misses and unservable entries")
struct FileSystemCacheMissTests {

    @Test("A read for an identifier that was never stashed reports nil")
    func readForAbsentIdentifierReportsNil() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)

        let retrieved = try await cache.resource(for: "never-stashed")

        #expect(retrieved == nil)
    }

    @Test("A remove for an identifier that was never stashed does not throw")
    func removeForAbsentIdentifierDoesNotThrow() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)

        await #expect(throws: Never.self) {
            try await cache.removeResource(for: "never-stashed")
        }
    }

    /// The condition an app update ships: the item's `Codable` shape changed, so every entry the
    /// previous version wrote now fails to decode.
    @Test("An entry whose payload no longer decodes reports nil and is cleared from disk")
    func undecodableEntryReportsNilAndIsCleared() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let entry = root.appending(path: try #require(regularFiles(under: root).first))
        try undecodableRecordData().write(to: entry)

        let retrieved = try await cache.resource(for: "1")

        #expect(retrieved == nil)
        #expect(FileManager.default.fileExists(atPath: entry.path) == false)
    }

    @Test("An entry whose payload no longer decodes can still be removed by identifier")
    func undecodableEntryIsRemovableByIdentifier() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let entry = root.appending(path: try #require(regularFiles(under: root).first))
        try undecodableRecordData().write(to: entry)

        try await cache.removeResource(for: "1")

        #expect(FileManager.default.fileExists(atPath: entry.path) == false)
    }

    /// The other half of the distinction. A fault must not be laundered into a miss, and the
    /// self-healing delete must not reach an entry that was merely unreadable this once.
    @Test("A read that fails for a reason other than a miss surfaces, and spares the entry")
    func genuineReadFailureSurfacesAndSparesTheEntry() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        try await makeCache(root: root, subfolder: nil)
            .stash(CodableTestValue(count: "1"), duration: .long)

        let written = regularFiles(under: root)
        let cache = makeCache(agent: UnreadableAgent(root: root), subfolder: nil)

        await #expect(throws: UnreadableAgent.ReadFailure.self) {
            _ = try await cache.resource(for: "1")
        }

        #expect(regularFiles(under: root) == written)
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
    makeCache(agent: SandboxAgent(root: root), subfolder: subfolder)
}

private func makeCache(
    agent: some FileSystemContext & Sendable,
    subfolder: String?
) -> FileSystemCache<CodableTestValue> {
    withDependencies {
        $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
            try FileSystemFolderStore(agent: agent, kind: directory, subfolder: folder)
        }
    } operation: {
        FileSystemCache(.documents, subfolder: subfolder)
    }
}

/// A sandbox whose reads always fail, standing in for a permissions or I/O fault on a file that
/// is demonstrably there. Everything else, including the existence check, is the real thing.
private struct UnreadableAgent: FileSystemContext, Sendable {

    /// The error every read fails with, distinct from anything `Files` or Foundation throws so
    /// that a test can tell it apart from a miss being reported as an error.
    struct ReadFailure: Error {}

    let sandbox: SandboxAgent

    init(root: URL) {
        self.sandbox = SandboxAgent(root: root)
    }

    func read(from url: URL) throws -> Data {
        throw ReadFailure()
    }

    func fileExists(at url: URL) -> Bool { sandbox.fileExists(at: url) }

    func folderExists(at url: URL) -> Bool { sandbox.folderExists(at: url) }

    func moveResource(from fromURL: URL, to toURL: URL) throws {
        try sandbox.moveResource(from: fromURL, to: toURL)
    }

    func copyResource(from fromURL: URL, to toURL: URL) throws {
        try sandbox.copyResource(from: fromURL, to: toURL)
    }

    func deleteLocation(at url: URL) throws { try sandbox.deleteLocation(at: url) }

    func createDirectory(at url: URL) throws { try sandbox.createDirectory(at: url) }

    func removeDirectory(at url: URL) throws { try sandbox.removeDirectory(at: url) }

    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        try sandbox.write(data, to: url, options: options)
    }

    func url(for directory: FileSystemDirectory) throws -> URL {
        try sandbox.url(for: directory)
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        try sandbox.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        )
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

/// Bytes in the shape of an entry, carrying an item that `CodableTestValue` cannot decode: its
/// `count` property is gone, which is what renaming a property in a shipped app leaves behind.
private func undecodableRecordData() -> Data {
    Data(#"{"item":{"quantity":1},"expiry":900000000}"#.utf8)
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
