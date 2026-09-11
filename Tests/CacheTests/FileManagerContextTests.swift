//
//  FileManagerContextTests.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Testing
import Foundation
import Files

@testable import Cache

/// Exercises the one method of ``FileManagerContext`` that is not a single forwarding call.
///
/// Every other method hands straight to `FileManager` and is line-for-line what the `SandboxAgent`
/// test helper does, so the on-disk suites already run the same code shape. `url(for:)` is the
/// exception: it branches, it passes `create: true`, and the on-disk suites never reach it,
/// because they substitute their own context and the live QuickStart test only ever nominates
/// `.temporary`. That left the three search-path cases in the shipped type untested, which is
/// exactly where a mapping mistake would sit: pointing `.caches` at the documents directory would
/// have passed everything.
@Suite("FileManagerContext directory resolution")
struct FileManagerContextTests {

    @Test("Each search-path directory resolves where FileManager says it should")
    func searchPathDirectoriesResolve() throws {

        let context = FileManagerContext()
        let manager = FileManager.default

        let cases: [(FileSystemDirectory, FileManager.SearchPathDirectory)] = [
            (.documents, .documentDirectory),
            (.caches, .cachesDirectory),
            (.applicationSupport, .applicationSupportDirectory)
        ]

        for (directory, searchPath) in cases {
            let expected = try #require(manager.urls(for: searchPath, in: .userDomainMask).first)
            let resolved = try context.url(for: directory)

            #expect(resolved.standardizedFileURL == expected.standardizedFileURL)
        }
    }

    /// The other branch. `.temporary` has no search path, so it is the one case that does not go
    /// through `FileManager.url(for:in:appropriateFor:create:)` at all.
    @Test("The temporary directory resolves to FileManager's temporary directory")
    func temporaryDirectoryResolves() throws {

        let resolved = try FileManagerContext().url(for: .temporary)

        #expect(
            resolved.standardizedFileURL
            == FileManager.default.temporaryDirectory.standardizedFileURL
        )
    }

    /// The three search-path cases must not collapse onto one another.
    ///
    /// The assertion above compares each case against the same API the implementation calls, so a
    /// mapping that sent every case to the same place would satisfy it only if `FileManager`
    /// agreed. This says the stronger thing directly, and does not depend on that.
    @Test("The four directories resolve to four distinct locations")
    func directoriesDoNotCollapse() throws {

        let context = FileManagerContext()

        let resolved = try [
            FileSystemDirectory.documents,
            .caches,
            .applicationSupport,
            .temporary
        ].map { try context.url(for: $0).standardizedFileURL.path }

        #expect(Set(resolved).count == resolved.count)
    }
}
