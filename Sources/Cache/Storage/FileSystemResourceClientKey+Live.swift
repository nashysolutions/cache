//
//  FileSystemResourceClientKey+Live.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Foundation
import Dependencies
import Files
import FoundationDependencies

/// Gives `fileSystemResourceClient` a live value, so that ``FileSystemCache`` writes to the real
/// file system out of the box.
///
/// ## What this fixes
///
/// `FileSystemResourceClientKey` is declared in `foundation-dependencies` as a
/// `TestDependencyKey`, so it has a `testValue` and no `liveValue`. Reading it from a live
/// context therefore resolved to `testValue`, which is a mock whose `saveResource` does nothing.
/// A consumer who had not written the dependency boilerplate got a cache that reported every
/// `stash` as a success and wrote nothing, and the only diagnostic was a `swift-dependencies`
/// runtime warning that a Release build does not surface.
///
/// ## Why the conformance is retroactive
///
/// The live value belongs in `foundation-dependencies`, beside the key it completes. Until it is
/// declared there, this package is the only place that can supply one, and supplying one means
/// conforming a type this package does not own to a protocol it does not own.
///
/// Two consequences follow, and both are consequences a consumer can be bitten by:
///
/// - **It is global.** `swift-dependencies` resolves a live value by asking at runtime whether
///   the key conforms to `DependencyKey`, so this conformance takes effect everywhere in a
///   binary that links `Cache`, including code that never imports it.
/// - **It cannot be declared twice.** A consumer who wrote the `@retroactive DependencyKey`
///   conformance that this package's QuickStart used to ask for now has a duplicate, and must
///   delete theirs. Supplying a client through `withDependencies` is unaffected, and is the
///   supported way to substitute a different file system.
///
/// ## Where the live value does not reach
///
/// **A test context, and an Xcode preview.** Both still get the silent mock, and for the same
/// underlying reason: the witness that decides is bound in `foundation-dependencies`, where the
/// `TestDependencyKey` conformance is declared, and a retroactive `DependencyKey` conformance in
/// this module cannot displace it.
///
/// - In a test context `swift-dependencies` resolves `testValue`, which exists and is the no-op
///   mock, whatever else is true.
/// - In a preview it resolves `previewValue`. `DependencyKey` supplies a default that returns
///   `liveValue`, but `TestDependencyKey` supplies one that returns `testValue`, and the latter
///   is the one already witnessed. `swift-dependencies` documents the rule on `DependencyKey`:
///   a `previewValue` must be provided in the same module as the `TestDependencyKey` conformance.
///   Measured on this branch: in a `.preview` context a stash succeeds, the read reports `nil`,
///   and no directory is created.
///
/// The preview case is worth stating separately because a preview is a developer surface, not a
/// harness. Someone building UI against a cache in a preview canvas has not opted into anything,
/// and will see a cache that appears to work and serves nothing.
///
/// Neither can be closed from this package: both `testValue` and `previewValue` are witnessed in
/// `foundation-dependencies`, and only one declaration of each can exist.
extension FileSystemResourceClientKey: @retroactive DependencyKey {

    /// A store factory backed by ``FileManagerContext``.
    ///
    /// The factory throws rather than degrading. `FileSystemFolderStore.init` resolves the
    /// nominated directory and creates the folder, so a directory that cannot be resolved or a
    /// folder that cannot be created surfaces as `FileManager`'s own error, and surfaces at the
    /// point of use rather than at construction of the cache.
    ///
    /// That keeps ``FileSystemCache/init(_:subfolder:)`` non-failing, which is right for two
    /// reasons: the cache touches no disk until it is used, and a directory that is writable when
    /// a cache is constructed can stop being writable afterwards, so a check at construction
    /// would be a guarantee this package cannot keep.
    ///
    /// It also keeps the reporting rule that ``FileSystemCache/resource(for:)`` already follows.
    /// A miss reports `nil` and an entry that no longer decodes reports `nil`, because neither is
    /// a fault. A cache directory that cannot be created is a fault, so it throws, and so is one
    /// that exists but cannot be searched: an identifier this cache cannot look for is not the
    /// same as one it does not hold.
    public static let liveValue = FileSystemResourceClient { directory, subfolder in
        try FileSystemFolderStore(
            agent: FileManagerContext(),
            kind: directory,
            subfolder: subfolder
        )
    }
}
