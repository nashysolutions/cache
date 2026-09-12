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
    ///
    /// The type component is part of what is pinned. It is not decoration: see
    /// `FileSystemCacheCrossTypeTests` for what its absence did.
    @Test("An entry is written to the documented path")
    func entryIsWrittenToTheDocumentedPath() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: "shared")
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let type = sha256Hex(String(reflecting: CodableTestValue.self))
        let digest = sha256Hex("1")

        #expect(regularFiles(under: root) == ["shared/cache-v2/\(type)/\(digest).cache"])
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

/// Exercises two caches over different item types sharing one directory.
///
/// This is the default configuration, not an exotic one: `subfolder` defaults to `nil`, so any
/// two caches an app creates over the same base directory land in the same place.
///
/// Entries used to be named from the item identifier alone, so two item types with equal
/// identifiers resolved to one file. The damage was not a stale read. Each cache overwrote the
/// other's entry, and each then failed to decode what it found, which is the exact condition the
/// self-healing delete acts on, so both entries were destroyed and both caches served nothing
/// from then on, permanently and without an error.
@Suite("FileSystemCache across item types")
struct FileSystemCacheCrossTypeTests {

    @Test("Two item types with the same identifier keep separate entries")
    func differentItemTypesDoNotShareAnEntry() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let alpha = makeCache(CodableTestValue.self, root: root, subfolder: nil)
        let beta = makeCache(OtherCodableTestValue.self, root: root, subfolder: nil)

        try await alpha.stash(CodableTestValue(count: "1"), duration: .long)
        try await beta.stash(OtherCodableTestValue(label: "1"), duration: .long)

        #expect(regularFiles(under: root).count == 2)
        #expect(try await alpha.resource(for: "1")?.count == "1")
        #expect(try await beta.resource(for: "1")?.label == "1")
    }

    @Test("A read by one item type does not delete another's entry")
    func readByOneItemTypeSparesAnother() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let alpha = makeCache(CodableTestValue.self, root: root, subfolder: nil)
        let beta = makeCache(OtherCodableTestValue.self, root: root, subfolder: nil)

        try await beta.stash(OtherCodableTestValue(label: "1"), duration: .long)
        let written = regularFiles(under: root)

        #expect(try await alpha.resource(for: "1") == nil)
        #expect(regularFiles(under: root) == written)
        #expect(try await beta.resource(for: "1")?.label == "1")
    }

    @Test("reset() on one item type's cache leaves another's entries alone")
    func resetSparesAnotherItemTypesEntries() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let alpha = makeCache(CodableTestValue.self, root: root, subfolder: nil)
        let beta = makeCache(OtherCodableTestValue.self, root: root, subfolder: nil)

        try await alpha.stash(CodableTestValue(count: "1"), duration: .long)
        try await beta.stash(OtherCodableTestValue(label: "1"), duration: .long)

        try await alpha.reset()

        #expect(try await alpha.resource(for: "1") == nil)
        #expect(try await beta.resource(for: "1")?.label == "1")
    }

    @Test("removeResource(for:) on one item type's cache leaves another's entry alone")
    func removeSparesAnotherItemTypesEntry() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let alpha = makeCache(CodableTestValue.self, root: root, subfolder: nil)
        let beta = makeCache(OtherCodableTestValue.self, root: root, subfolder: nil)

        try await alpha.stash(CodableTestValue(count: "1"), duration: .long)
        try await beta.stash(OtherCodableTestValue(label: "1"), duration: .long)

        try await alpha.removeResource(for: "1")

        #expect(try await beta.resource(for: "1")?.label == "1")
    }
}

/// Exercises a cache whose own folder has become unusable, against a real file system.
///
/// Each test stages the fault with POSIX permissions and asserts the staging took effect before
/// asserting anything about the cache. Without that check, a suite running as a user who ignores
/// the permission bits would report these as passing while exercising nothing.
@Suite("FileSystemCache file system faults")
struct FileSystemCacheFaultTests {

    /// The directory a cache writes its entries into, found without naming the layout.
    private func entryFolder(under root: URL) throws -> URL {
        let entry = try #require(regularFiles(under: root).first)
        return root.appending(path: entry).deletingLastPathComponent()
    }

    /// A cache directory that is there but cannot be searched is a fault, not an absence.
    ///
    /// `fileExists` answers "no" for an entry inside an unsearchable directory, so the existence
    /// check this code used to open with reported a permissions fault as an ordinary miss, for
    /// every identifier, silently. Foundation makes the two distinguishable only in the error: an
    /// absent file in a readable directory reports not-found, and the same absent file in an
    /// unsearchable one reports no-permission.
    @Test("A read in a directory that cannot be searched is a fault, not a miss")
    func unsearchableDirectoryIsAFaultOnRead() async throws {

        let root = try makeSandbox()
        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let folder = try entryFolder(under: root)
        let entry = folder.appending(
            component: try #require(FileManager.default.contentsOfDirectory(atPath: folder.path).first)
        )

        defer {
            try? setPermissions(0o755, on: folder)
            try? FileManager.default.removeItem(at: root)
        }

        try setPermissions(0o000, on: folder)

        // Positive control: without this, a process that ignores the permission bits would make
        // the expectation below pass without the fault ever having been staged.
        #expect(throws: (any Error).self) {
            _ = try Data(contentsOf: entry)
        }

        await #expect(throws: (any Error).self) {
            _ = try await cache.resource(for: "1")
        }
    }

    /// The same state, through the other call that used to guard on an existence check.
    @Test("A remove in a directory that cannot be searched is a fault, not a no-op")
    func unsearchableDirectoryIsAFaultOnRemove() async throws {

        let root = try makeSandbox()
        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let folder = try entryFolder(under: root)

        defer {
            try? setPermissions(0o755, on: folder)
            try? FileManager.default.removeItem(at: root)
        }

        try setPermissions(0o000, on: folder)

        #expect(throws: (any Error).self) {
            _ = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        }

        await #expect(throws: (any Error).self) {
            try await cache.removeResource(for: "1")
        }
    }

    /// Pins the error a consumer actually catches.
    ///
    /// Entries used to be written through `Files`' `saveResource`, which wraps every failure in
    /// `SaveResourceError`. That type is internal to `Files`, so a consumer could neither name it
    /// nor match on it, and the documented promise that a caller sees the file system's own error
    /// was false for every write and every delete. Writing through the file system context keeps
    /// that promise, and `CocoaError` is what makes it checkable: it is a type a consumer can
    /// spell.
    @Test("A write that fails surfaces the file system's own error")
    func writeFailureSurfacesTheFileSystemsOwnError() async throws {

        let root = try makeSandbox()
        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let folder = try entryFolder(under: root)

        defer {
            try? setPermissions(0o755, on: folder)
            try? FileManager.default.removeItem(at: root)
        }

        try setPermissions(0o555, on: folder)

        #expect(throws: (any Error).self) {
            try Data("x".utf8).write(to: folder.appending(component: "control.probe"))
        }

        await #expect(throws: CocoaError.self) {
            try await cache.stash(CodableTestValue(count: "2"), duration: .long)
        }
    }
}

/// Exercises ``FileSystemCache/removeExpired()`` against a real file system.
///
/// The observables are the count the sweep reports and which files survive it. Reading an expired
/// identifier back proves nothing here, because a read reports `nil` for an expired entry whether
/// or not the sweep removed it, so these tests count files rather than read them back.
@Suite("FileSystemCache expired-entry sweep")
struct FileSystemCacheSweepTests {

    @Test("Expired entries are deleted, live entries are kept, and the count says how many went")
    func sweepDeletesOnlyExpiredEntries() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "expired-a"), duration: expiredAnHourAgo())
        try await cache.stash(CodableTestValue(count: "expired-b"), duration: expiredAnHourAgo())
        try await cache.stash(CodableTestValue(count: "live"), duration: .long)
        #expect(regularFiles(under: root).count == 3)

        let removed = try await cache.removeExpired()

        #expect(removed == 2)
        #expect(regularFiles(under: root).count == 1)
        #expect(try await cache.resource(for: "live")?.count == "live")
    }

    @Test("A second sweep finds nothing, because the first removed the entries rather than only counting them")
    func secondSweepFindsNothing() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "expired"), duration: expiredAnHourAgo())

        #expect(try await cache.removeExpired() == 1)
        #expect(try await cache.removeExpired() == 0)
    }

    @Test("A sweep with nothing expired reports zero and deletes nothing")
    func sweepWithNothingExpiredReportsZero() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)
        try await cache.stash(CodableTestValue(count: "2"), duration: .long)
        let written = regularFiles(under: root)

        #expect(try await cache.removeExpired() == 0)
        #expect(regularFiles(under: root) == written)
    }

    @Test("A sweep of a cache that has never written reports zero rather than throwing")
    func sweepOfUnusedCacheReportsZero() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)

        #expect(try await cache.removeExpired() == 0)
    }

    /// The sweep decides by the `expiry` the file carries, not by whether the item decodes.
    ///
    /// This is the entry an app update leaves behind, and the one a sweep that decoded the whole
    /// entry to decide would skip. `FileSystemLayout.EntryExpiry` carries the reasoning.
    @Test("An expired entry whose item no longer decodes is removed and counted")
    func sweepRemovesExpiredEntryWhoseItemNoLongerDecodes() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let entry = root.appending(path: try #require(regularFiles(under: root).first))
        try undecodableRecordData(expiry: Date().addingTimeInterval(-3600)).write(to: entry)

        #expect(try await cache.removeExpired() == 1)
        #expect(FileManager.default.fileExists(atPath: entry.path) == false)
    }

    @Test("An unexpired entry whose item no longer decodes is left for the read path")
    func sweepSparesUnexpiredEntryWhoseItemNoLongerDecodes() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: .long)

        let entry = root.appending(path: try #require(regularFiles(under: root).first))
        try undecodableRecordData(expiry: Date().addingTimeInterval(3600)).write(to: entry)

        #expect(try await cache.removeExpired() == 0)
        #expect(FileManager.default.fileExists(atPath: entry.path))
    }

    /// Nothing about an empty file says it has expired, so the sweep leaves it. The read path
    /// already treats it as unservable and clears it when its identifier is next looked up.
    @Test("An entry whose expiry cannot be read is left in place and not counted")
    func sweepSparesEntryWhoseExpiryCannotBeRead() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: expiredAnHourAgo())

        let entry = root.appending(path: try #require(regularFiles(under: root).first))
        try Data().write(to: entry)

        #expect(try await cache.removeExpired() == 0)
        #expect(FileManager.default.fileExists(atPath: entry.path))
    }

    /// The same measurement `reset()` is held to: a file the cache did not write survives, even
    /// sitting beside the cache's own entries and even carrying an expiry that has passed.
    @Test("A foreign file beside the entries survives the sweep, even one shaped like an expired entry")
    func sweepSparesForeignFileBesideItsOwnEntries() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "expired"), duration: expiredAnHourAgo())

        let entry = try #require(regularFiles(under: root).first)
        let writeDirectory = root.appending(path: entry).deletingLastPathComponent()

        let neighbour = writeDirectory.appending(component: "unrelated-neighbour.json")
        let neighbourBody = undecodableRecordData(expiry: Date().addingTimeInterval(-3600))
        try neighbourBody.write(to: neighbour)

        #expect(try await cache.removeExpired() == 1)
        #expect((try? Data(contentsOf: neighbour)) == neighbourBody)
        #expect(regularFiles(under: root).count == 1)
    }

    @Test("A sweep by one item type's cache leaves another item type's expired entries alone")
    func sweepSparesAnotherItemTypesEntries() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let alpha = makeCache(CodableTestValue.self, root: root, subfolder: nil)
        let beta = makeCache(OtherCodableTestValue.self, root: root, subfolder: nil)

        try await alpha.stash(CodableTestValue(count: "1"), duration: expiredAnHourAgo())
        try await beta.stash(OtherCodableTestValue(label: "1"), duration: expiredAnHourAgo())

        #expect(try await alpha.removeExpired() == 1)
        #expect(regularFiles(under: root).count == 1)
        #expect(try await beta.removeExpired() == 1)
        #expect(regularFiles(under: root).isEmpty)
    }

    /// The rule the read and remove paths already follow: a folder that is there but cannot be
    /// searched is a fault, and a sweep that reported it as "nothing expired" would hide it.
    @Test("A sweep of a folder that cannot be searched is a fault, not zero")
    func unsearchableFolderIsAFaultOnSweep() async throws {

        let root = try makeSandbox()
        let cache = makeCache(root: root, subfolder: nil)
        try await cache.stash(CodableTestValue(count: "1"), duration: expiredAnHourAgo())

        let entry = try #require(regularFiles(under: root).first)
        let folder = root.appending(path: entry).deletingLastPathComponent()

        defer {
            try? setPermissions(0o755, on: folder)
            try? FileManager.default.removeItem(at: root)
        }

        try setPermissions(0o000, on: folder)

        // Positive control, as in the fault suite above: a process that ignores the permission
        // bits would otherwise pass the expectation below without the fault ever being staged.
        #expect(throws: (any Error).self) {
            _ = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        }

        await #expect(throws: (any Error).self) {
            _ = try await cache.removeExpired()
        }
    }

    /// An entry can vanish between the sweep listing it and reading it: another cache over the
    /// same folder, or the system purging the caches directory. That is an absence, not a fault,
    /// and the sweep carries on past it.
    @Test("An entry that vanishes before it is read is skipped, not counted, and does not stop the sweep")
    func entryVanishingBeforeReadIsSkipped() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let names = try await seedTwoExpiredEntries(under: root)
        let cache = makeCache(agent: SweepFaultAgent(root: root, vanishedOnRead: [names[0]]), subfolder: nil)

        #expect(try await cache.removeExpired() == 1)
        #expect(regularFiles(under: root).count == 1)
    }

    @Test("An entry that vanishes before it is deleted is skipped, not counted, and does not stop the sweep")
    func entryVanishingBeforeDeleteIsSkipped() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let names = try await seedTwoExpiredEntries(under: root)
        let cache = makeCache(agent: SweepFaultAgent(root: root, vanishedOnDelete: [names[0]]), subfolder: nil)

        #expect(try await cache.removeExpired() == 1)
        #expect(regularFiles(under: root).count == 1)
    }

    /// A read that fails for any reason other than absence is a fault. The sweep must not launder
    /// it into "nothing expired", and must not delete an entry it could not read.
    @Test("A read that fails for a reason other than absence is a fault, and spares every entry")
    func readFaultSurfacesAndSparesEntries() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await seedTwoExpiredEntries(under: root)
        let written = regularFiles(under: root)
        let cache = makeCache(agent: UnreadableAgent(root: root), subfolder: nil)

        await #expect(throws: UnreadableAgent.ReadFailure.self) {
            _ = try await cache.removeExpired()
        }

        #expect(regularFiles(under: root) == written)
    }

    /// The promise the doc comment makes about a fault part-way through: the error surfaces, and
    /// the entries removed before it stay removed. The agent lists in name order, so which entry
    /// the sweep reaches first is known rather than left to the file system.
    @Test("A delete that fails is a fault, and the entries removed before it stay removed")
    func deleteFaultSurfacesAfterPartialProgress() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let names = try await seedTwoExpiredEntries(under: root)
        let cache = makeCache(agent: SweepFaultAgent(root: root, undeletable: [names[1]]), subfolder: nil)

        await #expect(throws: SweepFaultAgent.DeleteFailure.self) {
            _ = try await cache.removeExpired()
        }

        let remaining = regularFiles(under: root).map { URL(filePath: $0).lastPathComponent }
        #expect(remaining == [names[1]])
    }

    /// Two expired entries, and their filenames in the order a `SweepFaultAgent` lists them.
    private func seedTwoExpiredEntries(under root: URL) async throws -> [String] {
        let seed = makeCache(root: root, subfolder: nil)
        try await seed.stash(CodableTestValue(count: "expired-a"), duration: expiredAnHourAgo())
        try await seed.stash(CodableTestValue(count: "expired-b"), duration: expiredAnHourAgo())
        return regularFiles(under: root).map { URL(filePath: $0).lastPathComponent }.sorted()
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
    makeCache(CodableTestValue.self, root: root, subfolder: subfolder)
}

private func makeCache(
    agent: some FileSystemContext & Sendable,
    subfolder: String?
) -> FileSystemCache<CodableTestValue> {
    makeCache(CodableTestValue.self, agent: agent, subfolder: subfolder)
}

private func makeCache<Item>(
    _ itemType: Item.Type,
    root: URL,
    subfolder: String?
) -> FileSystemCache<Item> {
    makeCache(itemType, agent: SandboxAgent(root: root), subfolder: subfolder)
}

private func makeCache<Item>(
    _ itemType: Item.Type,
    agent: some FileSystemContext & Sendable,
    subfolder: String?
) -> FileSystemCache<Item> {
    withDependencies {
        $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
            try FileSystemFolderStore(agent: agent, kind: directory, subfolder: folder)
        }
    } operation: {
        FileSystemCache<Item>(.documents, subfolder: subfolder)
    }
}

/// The lowercase hexadecimal SHA-256 of a string.
///
/// Spelled out here rather than read back from the package, so that a change to how the package
/// derives a path component fails a test instead of silently agreeing with itself.
func sha256Hex(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
}

/// Sets POSIX permissions on a directory, for the tests that stage a file system fault.
func setPermissions(_ permissions: Int, on url: URL) throws {
    try FileManager.default.setAttributes(
        [.posixPermissions: permissions],
        ofItemAtPath: url.path
    )
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

/// A sandbox that lists in name order and whose reads and deletes can be made to fail for chosen
/// files: as an absence, standing in for an entry that vanished after being listed, or as a fault.
/// Everything else is the real file system.
private struct SweepFaultAgent: FileSystemContext, Sendable {

    /// The error a chosen delete fails with, distinct from anything Foundation throws.
    struct DeleteFailure: Error {}

    let sandbox: SandboxAgent

    /// Filenames whose read reports not-found, as if deleted between listing and reading.
    let vanishedOnRead: Set<String>

    /// Filenames whose delete reports not-found, as if deleted between reading and deleting.
    let vanishedOnDelete: Set<String>

    /// Filenames whose delete fails for a reason that is not an absence.
    let undeletable: Set<String>

    init(
        root: URL,
        vanishedOnRead: Set<String> = [],
        vanishedOnDelete: Set<String> = [],
        undeletable: Set<String> = []
    ) {
        self.sandbox = SandboxAgent(root: root)
        self.vanishedOnRead = vanishedOnRead
        self.vanishedOnDelete = vanishedOnDelete
        self.undeletable = undeletable
    }

    func read(from url: URL) throws -> Data {
        if vanishedOnRead.contains(url.lastPathComponent) {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try sandbox.read(from: url)
    }

    func deleteLocation(at url: URL) throws {
        if vanishedOnDelete.contains(url.lastPathComponent) {
            throw CocoaError(.fileNoSuchFile)
        }
        if undeletable.contains(url.lastPathComponent) {
            throw DeleteFailure()
        }
        try sandbox.deleteLocation(at: url)
    }

    /// In name order, so a test can say which entry the sweep reaches first.
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        try sandbox.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func fileExists(at url: URL) -> Bool { sandbox.fileExists(at: url) }

    func folderExists(at url: URL) -> Bool { sandbox.folderExists(at: url) }

    func moveResource(from fromURL: URL, to toURL: URL) throws {
        try sandbox.moveResource(from: fromURL, to: toURL)
    }

    func copyResource(from fromURL: URL, to toURL: URL) throws {
        try sandbox.copyResource(from: fromURL, to: toURL)
    }

    func createDirectory(at url: URL) throws { try sandbox.createDirectory(at: url) }

    func removeDirectory(at url: URL) throws { try sandbox.removeDirectory(at: url) }

    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        try sandbox.write(data, to: url, options: options)
    }

    func url(for directory: FileSystemDirectory) throws -> URL {
        try sandbox.url(for: directory)
    }
}

/// Bytes in the shape of an entry, carrying an item that `CodableTestValue` cannot decode: its
/// `count` property is gone, which is what renaming a property in a shipped app leaves behind.
/// The expiry is far in the future, for the tests that are not about expiry.
private func undecodableRecordData() -> Data {
    undecodableRecordData(expiry: Date(timeIntervalSinceReferenceDate: 900_000_000))
}

/// The same bytes with a chosen expiry, written the way the package writes it, as seconds since
/// the reference date, so the sweep reads it as the package's own.
private func undecodableRecordData(expiry: Date) -> Data {
    Data(#"{"item":{"quantity":1},"expiry":\#(expiry.timeIntervalSinceReferenceDate)}"#.utf8)
}

/// An expiry that has already passed when it is stashed, so the entry is expired on the sweep that
/// follows without anything having to wait.
private func expiredAnHourAgo() -> Expiry {
    .custom(Date().addingTimeInterval(-3600))
}

/// Every regular file beneath `root`, as paths relative to it. Directories are excluded, so an
/// empty folder the cache created is invisible here.
///
/// Shared with `QuickStartTests`, which asks the same question of a real app directory rather
/// than of a sandbox.
func regularFiles(under root: URL) -> Set<String> {
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
