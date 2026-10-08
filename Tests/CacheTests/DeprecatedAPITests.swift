//
//  DeprecatedAPITests.swift
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

import Cache

/// Pins that code written against 6.0.0 still compiles and behaves as it did.
///
/// 6.0.0 made `Resource` and `CodableResource` public, its `Cache` protocol had no
/// `removeExpired()` requirement, and `FileSystemCache`'s initialiser took a `FileSystemDirectory`.
/// It also named four operations differently: `stash(_:duration:)`, `resource(for:)`,
/// `removeResource(for:)` and `reset()`, which are now `setItem(_:expiry:)`, `item(for:)`,
/// `removeItem(for:)` and `removeAll()`, and `Expiry.custom(_:)`, which is now `Expiry.at(_:)`.
/// Each test below is written the way a 6.0.0 consumer wrote it, so much of the suite's value is
/// that it compiles. Were a shim removed, or its shape changed, this file would stop building.
///
/// The import is deliberately not `@testable`: a consumer sees only the public surface, and the
/// package's own internal types must not stand in for the shims here. `Files` is imported because
/// a 6.0.0 consumer that held a `FileSystemDirectory` value had to import it to name the type.
/// `FoundationDependencies` is imported to point a file-backed cache at a sandbox.
///
/// The build reports a deprecation warning for each use of a shim below. Those are the warnings a
/// 6.0.0 consumer sees, and they are expected. They cannot be silenced by marking this suite
/// deprecated, because Swift Testing refuses a suite or test that is. They go when the shims and
/// this file are removed in 8.0.0.
@Suite("Deprecated 6.0.0 API")
struct DeprecatedAPITests {

    @Test("A Resource is built and read the way 6.0.0 code did")
    func resourceIsBuiltAndRead() async {

        let expiry = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let resource = Resource(item: TestValue(count: "1"), expiry: expiry)

        // Resource was Sendable in 6.0.0, so it can still cross into a detached task.
        let item = await Task.detached { resource.item }.value

        #expect(item == TestValue(count: "1"))
        #expect(resource.expiry == expiry)
    }

    @Test("Resources compare and hash by the item's identifier alone, as in 6.0.0")
    func resourceEqualityIsByIdentifier() {

        let older = Resource(
            item: TestDocument(id: "key", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )
        let newer = Resource(
            item: TestDocument(id: "key", body: "newer"),
            expiry: Date(timeIntervalSinceReferenceDate: 2_000_000)
        )
        let other = Resource(
            item: TestDocument(id: "other", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        #expect(older == newer)
        #expect(older != other)
        #expect(Set([older, newer, other]).count == 2)
    }

    @Test("A CodableResource round-trips through JSON with the keys 6.0.0 wrote")
    func codableResourceRoundTrips() throws {

        let resource = CodableResource(
            item: TestDocument(id: "key", body: "body"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        let data = try JSONEncoder().encode(resource)
        let decoded = try JSONDecoder().decode(CodableResource<TestDocument>.self, from: data)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(decoded.item == resource.item)
        #expect(decoded.expiry == resource.expiry)
        #expect(Set(object.keys) == ["item", "expiry"])
    }

    @Test("CodableResources compare and hash by the item's identifier alone, as in 6.0.0")
    func codableResourceEqualityIsByIdentifier() {

        let older = CodableResource(
            item: TestDocument(id: "key", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )
        let newer = CodableResource(
            item: TestDocument(id: "key", body: "newer"),
            expiry: Date(timeIntervalSinceReferenceDate: 2_000_000)
        )
        let other = CodableResource(
            item: TestDocument(id: "other", body: "older"),
            expiry: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        #expect(older == newer)
        #expect(older != other)
        #expect(Set([older, newer, other]).count == 2)
    }

    /// The default must not report a sweep that never ran. Returning `0` would tell the caller
    /// that nothing had expired, when nothing had been looked at.
    @Test("A 6.0.0 conformance without removeExpired() throws featureUnsupported when swept")
    func defaultRemoveExpiredThrowsUnsupported() async {

        let error = await #expect(throws: CocoaError.self) {
            try await sweep(SixPointZeroCache())
        }

        #expect(error?.code == .featureUnsupported)
    }

    /// The default is reached only by a conformance that has no sweep. Both caches in the package
    /// have one, and generic code over `Cache` must reach it, not the default.
    @Test("Generic code sweeping a package cache reaches its own sweep, not the default", .dependency(\.date.now, pinnedNow))
    func packageCacheDoesNotUseTheDefault() async throws {

        let cache = VolatileCache<TestValue>()
        try await cache.stash(TestValue(count: "expired"), duration: .custom(.distantPast))

        #expect(try await sweep(cache) == 1)
    }

    /// Only a call that passes a `FileSystemDirectory` value reaches the deprecated initialiser; a
    /// leading-dot call resolves to the `CacheDirectory` one. So the value is held in a variable
    /// here, as 6.0.0 code that chose its directory at run time held it. Where a cache built this
    /// way writes is pinned by `CacheDirectoryTests`.
    @Test("A FileSystemCache is built from a FileSystemDirectory value the way 6.0.0 code did", .dependency(\.date.now, pinnedNow))
    func fileSystemCacheIsBuiltFromAFileSystemDirectory() async throws {

        let directory: FileSystemDirectory = .caches

        let unscoped = FileSystemCache<TestDocument>(directory)
        let scoped = FileSystemCache<TestDocument>(directory, subfolder: "Cheeses")

        try await unscoped.stash(TestDocument(id: "1", body: "body"), duration: .long)
        try await scoped.stash(TestDocument(id: "1", body: "body"), duration: .long)
    }

    /// Each 6.0.0 name must do what its 7.0.0 name does on both package caches, which implement
    /// only the new names. Every step is read back through a new name, so a shim that did nothing,
    /// or that dropped its expiry, fails a step: an item set through `stash` with an expiry already
    /// past must not be served, which a shim that substituted a preset would serve.
    @Test(
        "Each 6.0.0 name does what its 7.0.0 name does on a package cache",
        .dependency(\.date.now, pinnedNow),
        arguments: Backend.allCases
    )
    func oldNamesDoWhatTheNewNamesDo(backend: Backend) async throws {

        let root = FileManager.default.temporaryDirectory
            .appending(component: "cache-deprecated-api-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        switch backend {
        case .volatile:
            try await callEachOldName(on: VolatileCache<TestDocument>())
        case .fileSystem:
            let cache = withDependencies {
                $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
                    try FileSystemFolderStore(agent: SandboxAgent(root: root), kind: directory, subfolder: folder)
                }
            } operation: {
                FileSystemCache<TestDocument>(.documents, subfolder: nil)
            }
            try await callEachOldName(on: cache)
        }
    }

    /// A conformance written against 6.0.0 implements the old names and none of the new ones. Code
    /// written against 7.0.0 calls the new names, and must reach that conformance's own
    /// implementations, with the arguments it was given. The conformance records the expiry it
    /// receives, so a default that forwarded a different one fails here.
    @Test("A 6.0.0 conformance is reached through the 7.0.0 names")
    func sixPointZeroConformanceIsReachedThroughTheNewNames() async throws {

        let cache = SixPointZeroCache()
        let brie = TestValue(count: "brie")
        let cheddar = TestValue(count: "cheddar")

        try await setItem(brie, expiry: .after(.seconds(90)), in: cache)
        #expect(try await item(for: brie.id, in: cache) == brie)
        #expect(await cache.store.expiry(for: brie.id) == .after(.seconds(90)))

        try await setItem(cheddar, expiry: .long, in: cache)
        try await removeItem(for: brie.id, in: cache)
        #expect(try await item(for: brie.id, in: cache) == nil)
        #expect(try await item(for: cheddar.id, in: cache) == cheddar)

        try await setItem(brie, expiry: .long, in: cache)
        try await setItem(cheddar, expiry: .long, in: cache)
        try await removeAll(in: cache)
        #expect(try await item(for: brie.id, in: cache) == nil)
        #expect(try await item(for: cheddar.id, in: cache) == nil)
    }

    @Test("Expiry.custom(_:) builds the same expiry as Expiry.at(_:)")
    func customIsAt() {

        let date = Date(timeIntervalSinceReferenceDate: 1_000_000)

        #expect(Expiry.custom(date) == .at(date))
        #expect(Expiry.custom(date) != .at(date.addingTimeInterval(1)))
    }

    /// `.short`, `.medium` and `.long` were cases in 6.0.0, and are presets now. Code that names
    /// one must get the length 6.0.0 documented for it.
    @Test("The presets are the lengths 6.0.0 documented")
    func presetsKeepTheirLengths() {
        #expect(Expiry.short == .after(.seconds(60)))
        #expect(Expiry.medium == .after(.seconds(180)))
        #expect(Expiry.long == .after(.seconds(3600)))
    }
}

/// Calls each 6.0.0 name on a cache that implements only the 7.0.0 names, and reads every result
/// back through a 7.0.0 name.
///
/// On both package caches each old name is satisfied by its default in Deprecated.swift, so a call
/// here reaches the same function a call on the concrete type does.
private func callEachOldName<C: Cache>(on cache: C) async throws where C.Item == TestDocument {

    let brie = TestDocument(id: "brie", body: "brie")
    let cheddar = TestDocument(id: "cheddar", body: "cheddar")
    let expired = TestDocument(id: "expired", body: "expired")

    try await cache.stash(brie, duration: .long)
    #expect(try await cache.item(for: brie.id) == brie)

    try await cache.stash(expired, duration: .custom(pinnedNow.addingTimeInterval(-1)))
    #expect(try await cache.item(for: expired.id) == nil)

    #expect(try await cache.resource(for: brie.id) == brie)
    #expect(try await cache.resource(for: "never-set") == nil)

    try await cache.setItem(cheddar, expiry: .long)
    try await cache.removeResource(for: brie.id)
    #expect(try await cache.item(for: brie.id) == nil)
    #expect(try await cache.item(for: cheddar.id) == cheddar)

    try await cache.setItem(brie, expiry: .long)
    try await cache.setItem(cheddar, expiry: .long)
    try await cache.reset()
    #expect(try await cache.item(for: brie.id) == nil)
    #expect(try await cache.item(for: cheddar.id) == nil)
}

/// Sweeps any cache the way generic consumer code does, through the protocol requirement.
private func sweep<C: Cache>(_ cache: C) async throws -> Int {
    try await cache.removeExpired()
}

// Generic code written against 7.0.0, which calls each operation by its new name through the
// protocol requirement, as code that accepts any `Cache` does.

private func setItem<C: Cache>(_ item: C.Item, expiry: Expiry, in cache: C) async throws {
    try await cache.setItem(item, expiry: expiry)
}

private func item<C: Cache>(for identifier: C.Item.ID, in cache: C) async throws -> C.Item? {
    try await cache.item(for: identifier)
}

private func removeItem<C: Cache>(for identifier: C.Item.ID, in cache: C) async throws {
    try await cache.removeItem(for: identifier)
}

private func removeAll<C: Cache>(in cache: C) async throws {
    try await cache.removeAll()
}

/// A conformance written against 6.0.0, whose `Cache` protocol had no `removeExpired()` and named
/// its operations `stash(_:duration:)`, `resource(for:)`, `removeResource(for:)` and `reset()`.
///
/// It implements every requirement 6.0.0 had and nothing more, so it compiles only because of the
/// defaults for `removeExpired()` and for the four 7.0.0 names. It keeps what it is given, and the
/// expiry each item was given, so a caller of the new names can see its own implementations ran.
private struct SixPointZeroCache: Cache {

    let store = SixPointZeroStore()

    func stash(_ item: TestValue, duration: Expiry) async throws {
        await store.set(item, expiry: duration)
    }

    func removeResource(for identifier: TestValue.ID) async throws {
        await store.remove(identifier)
    }

    func resource(for identifier: TestValue.ID) async throws -> TestValue? {
        await store.item(for: identifier)
    }

    func reset() async throws {
        await store.removeAll()
    }
}

/// The storage behind ``SixPointZeroCache``. Expiry is recorded, not enforced: the test is about
/// which implementation a call reaches, not about when an entry expires.
private actor SixPointZeroStore {

    private var entries: [TestValue.ID: (item: TestValue, expiry: Expiry)] = [:]

    func set(_ item: TestValue, expiry: Expiry) {
        entries[item.id] = (item, expiry)
    }

    func remove(_ identifier: TestValue.ID) {
        entries[identifier] = nil
    }

    func item(for identifier: TestValue.ID) -> TestValue? {
        entries[identifier]?.item
    }

    func expiry(for identifier: TestValue.ID) -> Expiry? {
        entries[identifier]?.expiry
    }

    func removeAll() {
        entries.removeAll()
    }
}
