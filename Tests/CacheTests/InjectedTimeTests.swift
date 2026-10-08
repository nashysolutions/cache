//
//  InjectedTimeTests.swift
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

/// Pins that both caches set and judge every expiry against the time `@Dependency(\.date)`
/// reports, up to the deadline itself.
///
/// Every step runs at a time chosen with `withDependencies`, so nothing waits and nothing depends
/// on when the suite runs. The instants are in 2001. A cache that read the wall clock at any of
/// the three places it needs the time, when stashing, looking up or sweeping, would therefore be
/// years out, and a step on one side of a deadline or the other would fail.
///
/// No clock is pinned for the suite as a whole. A step that ran outside ``at(_:_:)`` would read
/// the default, which inside a test records an issue, so a step that slipped out of its scope
/// fails rather than passing on the real clock.
///
/// The durations are spelled out here rather than read back from ``Expiry``, so a preset that
/// changed length fails a test instead of agreeing with itself. The import is deliberately not
/// `@testable`: the time a consumer controls is the one the public caches read.
@Suite("Expiry against an injected time")
struct InjectedTimeTests {

    /// Pins the boundary a lookup applies.
    ///
    /// An entry has expired once its deadline precedes the current time, so at the deadline
    /// itself it is still served. The lookups run in this order because a lookup that finds an
    /// entry expired also removes it.
    @Test(
        "A lookup serves an entry just before its deadline and at it, and not just after it",
        arguments: Backend.allCases, lifetimes
    )
    func lookupAppliesTheDeadline(backend: Backend, lifetime: Lifetime) async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(backend, root: root)
        let deadline = pinnedNow.addingTimeInterval(lifetime.seconds)

        try await at(pinnedNow) { try await cache.stash(document, duration: lifetime.expiry) }

        let justBefore = try await at(deadline.addingTimeInterval(-oneMillisecond)) {
            try await cache.resource(for: document.id)
        }
        let atTheDeadline = try await at(deadline) {
            try await cache.resource(for: document.id)
        }
        let justAfter = try await at(deadline.addingTimeInterval(oneMillisecond)) {
            try await cache.resource(for: document.id)
        }

        #expect(justBefore == document)
        #expect(atTheDeadline == document)
        #expect(justAfter == nil)
    }

    /// Pins that the sweep draws the same boundary as a lookup.
    ///
    /// The last lookup goes back to before the deadline. At that time the entry has not expired,
    /// so finding nothing there shows the sweep removed it, which a lookup after the deadline
    /// could not show: that lookup reports `nil` for an expired entry whether or not it was swept.
    @Test(
        "removeExpired() keeps an entry just before its deadline and at it, and removes it just after",
        arguments: Backend.allCases, lifetimes
    )
    func sweepAppliesTheDeadline(backend: Backend, lifetime: Lifetime) async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(backend, root: root)
        let deadline = pinnedNow.addingTimeInterval(lifetime.seconds)

        try await at(pinnedNow) { try await cache.stash(document, duration: lifetime.expiry) }

        let sweptJustBefore = try await at(deadline.addingTimeInterval(-oneMillisecond)) {
            try await cache.removeExpired()
        }
        let sweptAtTheDeadline = try await at(deadline) {
            try await cache.removeExpired()
        }
        let servedAfterBothSweeps = try await at(deadline) {
            try await cache.resource(for: document.id)
        }
        let sweptJustAfter = try await at(deadline.addingTimeInterval(oneMillisecond)) {
            try await cache.removeExpired()
        }
        let servedBeforeTheDeadlineAfterTheSweep = try await at(deadline.addingTimeInterval(-oneMillisecond)) {
            try await cache.resource(for: document.id)
        }

        #expect(sweptJustBefore == 0)
        #expect(sweptAtTheDeadline == 0)
        #expect(servedAfterBothSweeps == document)
        #expect(sweptJustAfter == 1)
        #expect(servedBeforeTheDeadlineAfterTheSweep == nil)
    }

    /// Pins that the time is read on every stash, not once for the cache.
    ///
    /// Two entries with the same preset are stashed 30 seconds apart, so each deadline is counted
    /// from its own stash. A cache that read the time once, when it was constructed or first used,
    /// would give both the same deadline.
    @Test("Each entry's deadline is counted from the time of its own stash", arguments: Backend.allCases)
    func eachDeadlineIsCountedFromItsOwnStash(backend: Backend) async throws {

        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let cache = makeCache(backend, root: root)
        let earlier = TestDocument(id: "earlier", body: "stashed first")
        let later = TestDocument(id: "later", body: "stashed 30 seconds after")

        try await at(pinnedNow) { try await cache.stash(earlier, duration: .short) }
        try await at(pinnedNow.addingTimeInterval(30)) { try await cache.stash(later, duration: .short) }

        let afterTheEarlierDeadline = pinnedNow.addingTimeInterval(61)
        let earlierServed = try await at(afterTheEarlierDeadline) { try await cache.resource(for: earlier.id) }
        let laterServed = try await at(afterTheEarlierDeadline) { try await cache.resource(for: later.id) }

        let afterTheLaterDeadline = pinnedNow.addingTimeInterval(91)
        let laterServedAfterItsOwn = try await at(afterTheLaterDeadline) { try await cache.resource(for: later.id) }

        #expect(earlierServed == nil)
        #expect(laterServed == later)
        #expect(laterServedAfterItsOwn == nil)
    }
}

// MARK: - Fixtures

/// The two caches, so that each test runs against both.
enum Backend: CaseIterable, Sendable {
    case volatile
    case fileSystem
}

/// An expiry, with its length spelled out.
struct Lifetime: Sendable, CustomTestStringConvertible {

    let expiry: Expiry

    /// How long after the stash the deadline falls.
    let seconds: TimeInterval

    let testDescription: String
}

/// Every preset, and a custom expiry, each stashed at ``pinnedNow``.
private let lifetimes = [
    Lifetime(expiry: .short, seconds: 60, testDescription: ".short"),
    Lifetime(expiry: .medium, seconds: 3 * 60, testDescription: ".medium"),
    Lifetime(expiry: .long, seconds: 60 * 60, testDescription: ".long"),
    Lifetime(expiry: .custom(pinnedNow.addingTimeInterval(90)), seconds: 90, testDescription: ".custom")
]

/// The item every boundary test stashes.
private let document = TestDocument(id: "1", body: "brie")

/// The step either side of a deadline.
private let oneMillisecond: TimeInterval = 0.001

/// Runs `operation` with `@Dependency(\.date)` reporting `instant`.
private func at<R>(_ instant: Date, _ operation: () async throws -> R) async rethrows -> R {
    try await withDependencies {
        $0.date.now = instant
    } operation: {
        try await operation()
    }
}

/// A cache of the given kind. The file-backed one writes to a real file system rooted at `root`.
private func makeCache(_ backend: Backend, root: URL) -> any Cache<TestDocument> {
    switch backend {
    case .volatile:
        return VolatileCache<TestDocument>()
    case .fileSystem:
        return withDependencies {
            $0.fileSystemResourceClient = FileSystemResourceClient { directory, folder in
                try FileSystemFolderStore(agent: SandboxAgent(root: root), kind: directory, subfolder: folder)
            }
        } operation: {
            FileSystemCache<TestDocument>(.documents, subfolder: nil)
        }
    }
}

/// A throwaway directory for one test.
private func makeSandbox() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(component: "cache-injected-time-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .standardizedFileURL
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
