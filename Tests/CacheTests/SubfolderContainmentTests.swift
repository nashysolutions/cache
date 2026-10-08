//
//  SubfolderContainmentTests.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import FoundationDependencies
import Files

@testable import Cache

/// Exercises the rule that keeps a ``FileSystemCache`` inside its base directory, whatever
/// subfolder it is given.
///
/// Every test runs in a sandbox laid out as `<sandbox>/base`, which the cache is given as its base
/// directory, beside `<sandbox>/outside`. An escape therefore lands somewhere these tests can see,
/// and not anywhere else on the machine running them.
///
/// The sandbox is not resolved, so on macOS it is spelled under `/var`, which is a link to
/// `/private/var`. A check that compared a resolved path with an unresolved one would refuse every
/// subfolder here, which the accepted cases below would catch.
@Suite("FileSystemCache subfolder containment", .dependency(\.date.now, pinnedNow))
struct SubfolderContainmentTests {

    @Test(
        "A subfolder that climbs out of the base directory is refused by every operation, and creates nothing outside it",
        arguments: ["..", "../x", "a/../..", "a/./../../x"]
    )
    func climbingSubfolderIsRefused(subfolder: String) async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        try await expectRefused(sandbox.makeCache(subfolder: subfolder), in: sandbox)
    }

    /// `..` is refused on sight rather than resolved, because after a link it climbs from the
    /// link's target, not from the link. Refusing it costs these two, which would stay inside.
    @Test("A `..` component is refused even where the path would stay inside", arguments: ["a/..", "a/../b"])
    func parentReferenceIsRefusedEvenWhenItStaysInside(subfolder: String) async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        try await expectRefused(sandbox.makeCache(subfolder: subfolder), in: sandbox)
    }

    @Test(
        "A subfolder through a link that points outside the base directory is refused",
        arguments: ["link", "link/x"]
    )
    func subfolderThroughOutwardLinkIsRefused(subfolder: String) async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        try sandbox.link("link", to: sandbox.outside)

        try await expectRefused(sandbox.makeCache(subfolder: subfolder), in: sandbox)
    }

    /// A folder whose path merely begins with the base directory's path is beside it, not inside
    /// it. Comparing the paths as strings would accept `<sandbox>/base-evil` as inside
    /// `<sandbox>/base`; comparing them component by component does not.
    @Test("A subfolder through a link to a sibling whose name begins with the base directory's is refused")
    func subfolderThroughLinkToPrefixedSiblingIsRefused() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let sibling = sandbox.root.appending(component: "base-evil", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try sandbox.link("link", to: sibling)

        try await expectRefused(sandbox.makeCache(subfolder: "link"), in: sandbox)
    }

    /// The case that resolving the path as text gets wrong. `link/../x` reads as `<base>/x`, and
    /// the file system puts it beside the link's target, which is outside.
    @Test("`..` after a link that points outside is refused")
    func parentReferenceAfterOutwardLinkIsRefused() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let deep = sandbox.outside.appending(component: "deep", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try sandbox.link("link", to: deep)

        try await expectRefused(sandbox.makeCache(subfolder: "link/../x"), in: sandbox)
    }

    /// Where a link with no target would lead cannot be shown to be inside, so it is not trusted.
    @Test("A subfolder through a link that cannot be followed is refused")
    func subfolderThroughDanglingLinkIsRefused() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        try sandbox.link("link", to: sandbox.outside.appending(component: "missing"))

        try await expectRefused(sandbox.makeCache(subfolder: "link"), in: sandbox)
    }

    /// The check covers the whole folder, not only the part a consumer supplies, so a link in
    /// place of the cache's own folder is refused too, with no subfolder at all.
    @Test("A link in place of the cache's own folder is refused")
    func linkInPlaceOfTheCachesOwnFolderIsRefused() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        try sandbox.link(FileSystemLayout.versionFolderName, to: sandbox.outside)

        try await expectRefused(sandbox.makeCache(subfolder: nil), in: sandbox)
    }

    /// `""` and `"."` name the base directory itself, so their entries land where `nil` puts them.
    @Test(
        "A subfolder that stays inside the base directory is accepted, and its entry is written there",
        arguments: [("", ""), (".", ""), ("a", "a/"), ("a/b", "a/b/")]
    )
    func subfolderInsideTheBaseDirectoryIsAccepted(subfolder: String, prefix: String) async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let cache = sandbox.makeCache(subfolder: subfolder)
        let before = sandbox.itemsOutsideBase()

        try await cache.setItem(CodableTestValue(count: "1"), expiry: .long)

        #expect(try await cache.item(for: "1")?.count == "1")
        #expect(regularFiles(under: sandbox.base) == ["\(prefix)\(entryPath(for: "1"))"])
        #expect(sandbox.itemsOutsideBase() == before)
    }

    /// Both joins treat a leading `/` as a separator, so an absolute path lands below the base
    /// directory rather than at the root. The path used names the sandbox's own outside folder
    /// rather than something like `/tmp/x`, so that if the join ever changed, the entry would land
    /// in the sandbox, where this test sees it, and not on the machine running it.
    @Test("A subfolder with a leading slash lands below the base directory, not at the root")
    func subfolderWithLeadingSlashLandsBelowTheBaseDirectory() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let absolute = sandbox.outside.appending(component: "x").path
        let cache = sandbox.makeCache(subfolder: absolute)

        try await cache.setItem(CodableTestValue(count: "1"), expiry: .long)

        #expect(try await cache.item(for: "1")?.count == "1")
        #expect(regularFiles(under: sandbox.outside).isEmpty)

        let written = regularFiles(under: sandbox.base)
        #expect(written.count == 1)
        #expect(written.allSatisfy { $0.hasSuffix("outside/x/\(entryPath(for: "1"))") })
    }

    /// The other half of following links: one that stays inside is followed, not refused, and
    /// the entry is written where the link leads.
    @Test("A subfolder through a link that stays inside the base directory is accepted")
    func subfolderThroughInwardLinkIsAccepted() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let inner = sandbox.base.appending(component: "inner", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try sandbox.link("alias", to: inner)

        let cache = sandbox.makeCache(subfolder: "alias")

        try await cache.setItem(CodableTestValue(count: "1"), expiry: .long)

        #expect(try await cache.item(for: "1")?.count == "1")
        #expect(regularFiles(under: sandbox.base) == ["inner/\(entryPath(for: "1"))"])
    }
}

/// Exercises a symbolic link at an entry's own filename, which the folder check above does not
/// reach: the folder is inside the base directory, and only the entry's last component leads out.
///
/// Each test plants the link where the cache's entry for `"1"` goes, pointing at a file in
/// `<sandbox>/outside`, and asserts on that file's bytes afterwards. A cache that followed the
/// link would change them, or would serve them.
@Suite("FileSystemCache entry filename links", .dependency(\.date.now, pinnedNow))
struct EntryFilenameLinkTests {

    @Test("Setting an item over a link at the entry's filename leaves the link's target unchanged, and writes the entry inside the base directory")
    func setItemOverOutwardLinkLeavesTheTargetUnchanged() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let target = sandbox.outside.appending(component: "target")
        let original = Data("not the cache's to change".utf8)
        try original.write(to: target)

        let entry = try sandbox.linkEntry(for: "1", to: target)
        let cache = sandbox.makeCache(subfolder: nil)
        let before = sandbox.itemsOutsideBase()

        try await cache.setItem(CodableTestValue(count: "1"), expiry: .long)

        #expect(try Data(contentsOf: target) == original)
        #expect(sandbox.itemsOutsideBase() == before)
        #expect(isSymbolicLink(entry) == false)
        #expect(regularFiles(under: sandbox.base) == [entryPath(for: "1")])
        #expect(try await cache.item(for: "1")?.count == "1")
    }

    /// A write that follows a link creates the target when it is missing, so a link to a path
    /// that does not exist yet is the way to plant a new file outside, rather than change one.
    @Test("Setting an item over a link to a missing file creates nothing outside the base directory")
    func setItemOverDanglingLinkCreatesNothingOutside() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let target = sandbox.outside.appending(component: "planted")
        let entry = try sandbox.linkEntry(for: "1", to: target)
        let cache = sandbox.makeCache(subfolder: nil)

        try await cache.setItem(CodableTestValue(count: "1"), expiry: .long)

        // Listed directly rather than through `itemsOutsideBase()`, whose enumeration reports a
        // link that cannot be followed under a different spelling of the sandbox's path.
        #expect(try FileManager.default.contentsOfDirectory(atPath: sandbox.outside.path).isEmpty)
        #expect(isSymbolicLink(entry) == false)
        #expect(regularFiles(under: sandbox.base) == [entryPath(for: "1")])
    }

    /// The target is a real entry for `"1"`, moved outside, so a read that followed the link would
    /// have something to serve. Reporting `nil` therefore shows the link was not followed, rather
    /// than that what it led to did not decode.
    @Test("A read through a link at the entry's filename reports nil, deletes the link, and leaves its target unchanged")
    func readThroughOutwardLinkServesNothing() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let cache = sandbox.makeCache(subfolder: nil)
        try await cache.setItem(CodableTestValue(count: "1"), expiry: .long)

        let entry = sandbox.base.appending(path: entryPath(for: "1"))
        let target = sandbox.outside.appending(component: "target")
        try FileManager.default.moveItem(at: entry, to: target)
        let original = try Data(contentsOf: target)
        try FileManager.default.createSymbolicLink(at: entry, withDestinationURL: target)

        #expect(try await cache.item(for: "1") == nil)
        #expect(isSymbolicLink(entry) == false)
        #expect(try Data(contentsOf: target) == original)
        #expect(regularFiles(under: sandbox.outside) == ["target"])
    }

    @Test("A remove with a link at the entry's filename deletes the link, not its target")
    func removeDeletesTheLinkNotItsTarget() async throws {

        let sandbox = try Sandbox()
        defer { sandbox.remove() }

        let target = sandbox.outside.appending(component: "target")
        let original = Data("not the cache's to delete".utf8)
        try original.write(to: target)

        let entry = try sandbox.linkEntry(for: "1", to: target)
        let cache = sandbox.makeCache(subfolder: nil)
        let before = sandbox.itemsOutsideBase()

        try await cache.removeItem(for: "1")

        #expect(isSymbolicLink(entry) == false)
        #expect(try Data(contentsOf: target) == original)
        #expect(sandbox.itemsOutsideBase() == before)
    }
}

/// Whether there is a symbolic link at a location, without following it.
private func isSymbolicLink(_ location: URL) -> Bool {
    (try? FileManager.default.destinationOfSymbolicLink(atPath: location.path)) != nil
}

/// Expects every operation on a cache to be refused with the containment error, and nothing to be
/// created anywhere in the sandbox: not outside the base directory, and not below it either, folders
/// included. The base directory already exists, so the one thing an operation may create before
/// it is refused, the base directory itself, is not created here.
private func expectRefused(
    _ cache: FileSystemCache<CodableTestValue>,
    in sandbox: Sandbox,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {

    let before = sandbox.allItems()

    let operations: [(String, () async throws -> Void)] = [
        ("setItem(_:expiry:)", { try await cache.setItem(CodableTestValue(count: "1"), expiry: .long) }),
        ("item(for:)", { _ = try await cache.item(for: "1") }),
        ("removeItem(for:)", { try await cache.removeItem(for: "1") }),
        ("removeAll()", { try await cache.removeAll() }),
        ("removeExpired()", { try await cache.removeExpired() })
    ]

    for (name, operation) in operations {
        let error = await #expect(throws: CocoaError.self, "\(name)", sourceLocation: sourceLocation) {
            try await operation()
        }
        #expect(error?.code == .fileWriteInvalidFileName, "\(name)", sourceLocation: sourceLocation)

        // The error names the folder that was refused, which is the cache's own type folder.
        #expect(
            error?.url?.lastPathComponent == sha256Hex(String(reflecting: CodableTestValue.self)),
            "\(name)",
            sourceLocation: sourceLocation
        )
    }

    #expect(sandbox.allItems() == before, sourceLocation: sourceLocation)
}

/// The path of an entry below its subfolder, spelled out here rather than read back from the
/// package, as `FileSystemCacheDiskTests` does.
private func entryPath(for identifier: String) -> String {
    "cache-v2/\(sha256Hex(String(reflecting: CodableTestValue.self)))/\(sha256Hex(identifier)).cache"
}

/// A throwaway directory holding a base directory for a cache and a folder outside it.
private struct Sandbox {

    let root: URL

    var base: URL {
        root.appending(component: "base", directoryHint: .isDirectory)
    }

    var outside: URL {
        root.appending(component: "outside", directoryHint: .isDirectory)
    }

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(component: "cache-containment-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    }

    /// Places a symbolic link inside the base directory.
    func link(_ name: String, to destination: URL) throws {
        try FileManager.default.createSymbolicLink(
            at: base.appending(component: name),
            withDestinationURL: destination
        )
    }

    /// Places a symbolic link at the filename a cache with no subfolder uses for an identifier's
    /// entry, creating the folders above it.
    ///
    /// - Returns: The location of the link.
    func linkEntry(for identifier: String, to destination: URL) throws -> URL {
        let entry = base.appending(path: entryPath(for: identifier))
        try FileManager.default.createDirectory(
            at: entry.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: entry, withDestinationURL: destination)
        return entry
    }

    /// A cache whose base directory is `base`, whichever directory it nominates.
    func makeCache(subfolder: String?) -> FileSystemCache<CodableTestValue> {
        let agent = SandboxAgent(root: base)
        return withDependencies {
            $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
                try FileSystemFolderStore(agent: agent, kind: directory, subfolder: folder)
            }
        } operation: {
            FileSystemCache<CodableTestValue>(.documents, subfolder: subfolder)
        }
    }

    /// Every file, folder and link in the sandbox, as paths relative to it. Links are listed, not
    /// followed.
    func allItems() -> Set<String> {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        let prefix = root.path + "/"
        var paths: Set<String> = []

        for case let url as URL in enumerator {
            let path = url.standardizedFileURL.path
            paths.insert(path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path)
        }

        return paths
    }

    /// Every file, folder and link in the sandbox that is not inside the base directory.
    func itemsOutsideBase() -> Set<String> {
        allItems().filter { $0 != "base" && $0.hasPrefix("base/") == false }
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
