//
//  CacheDirectoryTests.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Testing
import Foundation
import Dependencies
import FoundationDependencies
import Files

import Cache

/// Pins that every ``CacheDirectory`` case writes where the `FileSystemDirectory` case of the same
/// name did.
///
/// An adopter moving from the deprecated initialiser to the ``CacheDirectory`` one must find their
/// entries where they left them. A case that resolved to a different directory would compile, run
/// and report no error, and every entry written before the move would silently stop being found.
///
/// Each `FileSystemDirectory` resolves here to a folder of its own, named after it, so where an
/// entry lands says which directory the cache asked for. The test is run once per case, from
/// `allCases`, so a case added to ``CacheDirectory`` is covered without anyone remembering to add
/// it, and its expectation must be written into ``expectedDirectory(for:)`` before this compiles.
///
/// The import is deliberately not `@testable`. What is pinned is what an adopter observes through
/// the public initialisers, not the package's internal mapping, which could be right while the
/// initialiser ignored it.
///
/// The build reports one deprecation warning for this file, for the deprecated initialiser this
/// suite compares against. It goes with that initialiser in 8.0.0, and the comparison with it goes
/// too, leaving the check against ``expectedDirectory(for:)``.
@Suite("CacheDirectory resolves where FileSystemDirectory did")
struct CacheDirectoryTests {

    /// The `FileSystemDirectory` an adopter passed to the deprecated initialiser to mean the same
    /// place as `directory`.
    ///
    /// It is written out here rather than read from the package, so that the expectation is
    /// stated independently of the mapping it checks.
    static func expectedDirectory(for directory: CacheDirectory) -> FileSystemDirectory {
        switch directory {
        case .documents: .documents
        case .caches: .caches
        case .applicationSupport: .applicationSupport
        case .temporary: .temporary
        }
    }

    @Test("A cache built with a CacheDirectory writes where one built with the FileSystemDirectory of the same name did", arguments: CacheDirectory.allCases)
    func writesWhereTheDeprecatedInitialiserDid(directory: CacheDirectory) async throws {

        let expected = Self.expectedDirectory(for: directory)

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let viaCacheDirectory = try await pathsWritten(under: root.appending(component: "new")) {
            FileSystemCache<CodableTestValue>(directory, subfolder: "mapped")
        }

        let viaFileSystemDirectory = try await pathsWritten(under: root.appending(component: "old")) {
            FileSystemCache<CodableTestValue>(expected, subfolder: "mapped")
        }

        #expect(viaCacheDirectory.count == 1)
        #expect(viaCacheDirectory.allSatisfy { $0.hasPrefix("\(expected)/mapped/") })
        #expect(viaCacheDirectory == viaFileSystemDirectory)
    }
}

/// Stashes one entry through the cache `makeCache` builds, and returns the paths of the files
/// written, relative to `root`.
///
/// Each `FileSystemDirectory` the cache asks for resolves to its own folder below `root`, named
/// after the case, so the first component of every path returned is the directory asked for.
///
/// - Parameters:
///   - root: The folder the stand-in directories are created in.
///   - makeCache: Builds the cache. It is called inside the dependency scope, because a cache
///     resolves its file system client when it is constructed.
/// - Returns: The relative paths of the regular files below `root` after the stash.
private func pathsWritten(
    under root: URL,
    by makeCache: () -> FileSystemCache<CodableTestValue>
) async throws -> Set<String> {

    let cache = withDependencies {
        $0.fileSystemResourceClient = FileSystemResourceClient { requested, subfolder in
            let folder = root.appending(
                component: String(describing: requested),
                directoryHint: .isDirectory
            )
            return try FileSystemFolderStore(
                agent: SandboxAgent(root: folder),
                kind: requested,
                subfolder: subfolder
            )
        }
    } operation: {
        makeCache()
    }

    try await cache.stash(CodableTestValue(count: "1"), duration: .long)

    return regularFiles(under: root)
}

/// A throwaway directory for one test to write below.
private func makeSandbox() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(component: "cache-directory-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .standardizedFileURL
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
