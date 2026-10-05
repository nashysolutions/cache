//
//  IdentifierTypeTests.swift
//  cache
//
//  Created by Robert Nash on 05/10/2026.
//

import Testing
import Foundation
import CryptoKit
import Dependencies
import FoundationDependencies
import Files

import Cache

/// Pins which identifier types each cache accepts.
///
/// Much of this suite's value is that it compiles. 6.0.0 required every identifier to be
/// `LosslessStringConvertible`, which `UUID` is not, so the commonest `Identifiable` shape could
/// not be cached at all. `VolatileCache` never converts an identifier to text, and
/// `FileSystemCache` needs only its `description`, so neither has a reason to refuse `UUID`. Were
/// either constraint tightened again, this file would stop compiling.
///
/// The import is deliberately not `@testable`: the point is what a consumer can write.
@Suite("Identifier types")
struct IdentifierTypeTests {

    /// The shape most SwiftUI apps give a model, and the one 6.0.0 could not cache.
    struct UUIDKeyedItem: Identifiable, Codable, Sendable, Equatable {
        let id: UUID
        let name: String
    }

    /// An identifier type that was accepted before, and must still be.
    struct IntKeyedItem: Identifiable, Codable, Sendable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: - VolatileCache

    @Test("A UUID-keyed item round-trips through VolatileCache")
    func uuidKeyedItemRoundTripsThroughVolatileCache() async throws {

        let cache = VolatileCache<UUIDKeyedItem>()
        let item = UUIDKeyedItem(id: UUID(), name: "Brie")

        try await cache.stash(item, duration: .long)

        #expect(try await cache.resource(for: item.id) == item)
        #expect(try await cache.resource(for: UUID()) == nil)
    }

    @Test("An Int-keyed item still round-trips through VolatileCache")
    func intKeyedItemRoundTripsThroughVolatileCache() async throws {

        let cache = VolatileCache<IntKeyedItem>()
        let item = IntKeyedItem(id: 1, name: "Brie")

        try await cache.stash(item, duration: .long)

        #expect(try await cache.resource(for: 1) == item)
        #expect(try await cache.resource(for: 2) == nil)
    }

    // MARK: - FileSystemCache

    /// The read goes through a second cache over the same directory, standing in for the next
    /// launch. An entry can only be found that way if the identifier derives the same filename
    /// both times.
    @Test("A UUID-keyed item round-trips through FileSystemCache on a real file system")
    func uuidKeyedItemRoundTripsThroughFileSystemCache() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = UUIDKeyedItem(id: UUID(), name: "Brie")

        try await makeCache(UUIDKeyedItem.self, root: root).stash(item, duration: .long)

        let relaunched = makeCache(UUIDKeyedItem.self, root: root)

        #expect(try await relaunched.resource(for: item.id) == item)
        #expect(try await relaunched.resource(for: UUID()) == nil)
        #expect(entryPaths(under: root).count == 1)
    }

    @Test("An Int-keyed item still round-trips through FileSystemCache on a real file system")
    func intKeyedItemRoundTripsThroughFileSystemCache() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = IntKeyedItem(id: 1, name: "Brie")

        try await makeCache(IntKeyedItem.self, root: root).stash(item, duration: .long)

        let relaunched = makeCache(IntKeyedItem.self, root: root)

        #expect(try await relaunched.resource(for: 1) == item)
        #expect(try await relaunched.resource(for: 2) == nil)
    }

    /// Mirrors "An entry is written to the documented path" for a `UUID` identifier.
    ///
    /// The digest is taken of the UUID's text spelled out as a literal, not of `description` read
    /// back at run time. Admitting `UUID` made that text part of the on-disk format, so if
    /// Foundation ever rendered a UUID differently, every UUID-keyed entry would move, and this
    /// test is where that should show.
    @Test("A UUID-keyed entry is written to the documented path")
    func uuidKeyedEntryIsWrittenToTheDocumentedPath() async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let text = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        let identifier = try #require(UUID(uuidString: text))

        let cache = makeCache(UUIDKeyedItem.self, root: root, subfolder: "shared")
        try await cache.stash(UUIDKeyedItem(id: identifier, name: "Brie"), duration: .long)

        let type = hexDigest(of: String(reflecting: UUIDKeyedItem.self))
        let digest = hexDigest(of: text)

        #expect(identifier.description == text)
        #expect(entryPaths(under: root) == ["shared/cache-v2/\(type)/\(digest).cache"])
    }

    // MARK: - Fixtures

    /// A throwaway directory for one test.
    private func makeSandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "cache-identifier-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A cache over a real file system rooted at `root`, built the way the disk tests build theirs.
    private func makeCache<Item>(
        _ itemType: Item.Type,
        root: URL,
        subfolder: String? = nil
    ) -> FileSystemCache<Item> {
        withDependencies {
            $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
                try FileSystemFolderStore(agent: SandboxAgent(root: root), kind: directory, subfolder: folder)
            }
        } operation: {
            FileSystemCache<Item>(.documents, subfolder: subfolder)
        }
    }

    /// The lowercase hexadecimal SHA-256 of a string, spelled out here rather than read back from
    /// the package, so that a change to how the package derives a path fails this suite instead of
    /// agreeing with itself.
    private func hexDigest(of string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Every regular file beneath `root`, as paths relative to it.
    private func entryPaths(under root: URL) -> Set<String> {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return []
        }

        let prefix = root.path + "/"
        var paths: Set<String> = []

        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                continue
            }
            let path = url.standardizedFileURL.path
            paths.insert(path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path)
        }

        return paths
    }
}
