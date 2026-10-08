//
//  FileSystemCache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

/// A persistent, file system–backed cache for identifiable and codable items.
///
/// `FileSystemCache` provides expiry-aware, asynchronous caching of items that are stored on
/// disk. It is suitable for use cases where data must be retained across app launches.
///
/// Each item is written with its expiry as one JSON file, which is why `Item` must be `Codable`.
///
/// Entries are written into a folder below the directory you nominate, scoped to both the layout
/// version and `Item`, and never directly into the directory itself. The cache therefore only
/// ever deletes files it wrote itself, and it never deletes a directory. See <doc:OnDiskFormat>
/// for the layout and for what happens to entries written by an earlier version.
///
/// Two caches over different item types may share a directory, and a subfolder, without seeing
/// each other. That isolation is structural rather than advisory: it comes from the path, so
/// neither cache can read, overwrite, or clear the other's entries.
///
/// The initialiser touches no disk, and cannot fail. A directory that cannot be resolved,
/// created or searched is therefore reported by the first operation that needs it, not by
/// construction. This is deliberate: a directory that is usable when a cache is built can stop
/// being usable afterwards, so a check at construction would be a guarantee this package could
/// not keep.
///
/// The same holds for a subfolder that leads outside the directory you nominate. Every operation
/// checks the folder it is about to use before creating anything below that directory, and
/// refuses one that resolves outside it by throwing `CocoaError.fileWriteInvalidFileName`, so the
/// cache never writes outside it. See ``init(_:subfolder:)`` for what a subfolder may contain.
///
/// - Important: On a non-sandboxed macOS process, `.documents` is the user's real `~/Documents`.
///   A cache nominating it will create a folder there on first use. Before this package shipped a
///   live file system client, that write silently went nowhere, so an app that nominated
///   `.documents` and appeared to write nothing now writes something.
public struct FileSystemCache<Item: Identifiable & Codable & Sendable>: DatabaseBackedCache where Item.ID: Sendable & CustomStringConvertible {

    /// The backing file system–based database.
    let database: FileSystemDatabase<Item>

    /// Creates a new file system–backed cache.
    ///
    /// `Item.ID` must be `CustomStringConvertible` because an entry's filename is a digest of the
    /// identifier's `description`. That text must therefore be the same for an identifier on every
    /// launch, or an entry written on one launch is not found on the next, and different for
    /// different identifiers, or two items share one entry and each overwrites the other. `UUID`,
    /// `String` and the integer types meet both conditions. The compiler can check neither, so a
    /// `description` that includes a memory address, or anything else that varies, still compiles,
    /// and the cache then fails to find what it wrote.
    ///
    /// ## Subfolder
    ///
    /// A subfolder is a path below `fileSystemDirectory`, and may be nested, such as
    /// `"Cheeses/Soft"`. It must stay inside that directory, and every operation refuses one that
    /// does not by throwing `CocoaError.fileWriteInvalidFileName`, carrying the folder's location
    /// in the error's `url`. Nothing is created or written below `fileSystemDirectory` when that
    /// happens. The directory itself is still created if it is missing, because every operation
    /// resolves it first in order to check the subfolder against it. A subfolder is refused when:
    ///
    /// - it has a `..` component, such as `"../Documents"` or `"a/../b"`, wherever it would lead;
    /// - it passes through a symbolic link that leads outside the directory, or one that cannot be
    ///   followed.
    ///
    /// A symbolic link that stays inside the directory is followed. A leading `/` does not make
    /// the subfolder absolute: `"/Cheeses"` is the same folder as `"Cheeses"`. An empty string and
    /// `"."` both name the directory itself, like `nil`.
    ///
    /// Check a subfolder derived from anything you do not fully control, such as user input or a
    /// name supplied by a server, before passing it here. The rule above stops it escaping the
    /// directory; it does not stop it naming a different folder inside it.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The root directory in which resources will be stored.
    ///   - subfolder: An optional path below `fileSystemDirectory` used to scope the cache
    ///     contents. Defaults to `nil`.
    public init(
        _ fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil
    ) {
        database = FileSystemDatabase<Item>(
            fileSystemDirectory: fileSystemDirectory,
            subfolder: subfolder
        )
    }

    /// Stashes an item in the cache with a given expiry duration.
    ///
    /// If a resource with the same identifier already exists, it is replaced.
    ///
    /// - Parameters:
    ///   - item: The item to cache.
    ///   - duration: The expiry policy to apply.
    /// - Throws: An error if the item could not be saved to disk.
    public func stash(_ item: Item, duration: Expiry) async throws {
        let resource = CodableEntry(item: item, expiry: duration.date())
        try await database.stash(resource)
    }

    /// Removes a specific item from the cache, if present.
    ///
    /// The entry is deleted without being read, so an entry whose stored payload no longer
    /// decodes is removed like any other. Removing an identifier the cache holds nothing for
    /// does nothing and is not an error.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: An error if an entry is present and could not be deleted.
    public func removeResource(for identifier: Item.ID) async throws {
        try await database.removeResource(for: identifier)
    }

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// An identifier the cache holds nothing for reports `nil`, not an error, so a lookup before
    /// anything has been stashed behaves like any other miss. An entry whose stored payload no
    /// longer decodes, which is what an item's changed `Codable` shape leaves behind after an app
    /// update, also reports `nil`, and is deleted rather than left on disk unreadable.
    ///
    /// An error means the lookup could not be completed: a failure to read an entry that is
    /// there, or a cache directory that cannot be created or searched. An identifier this cache
    /// cannot look for is not the same as one it does not hold, so the former throws. That is
    /// worth catching; a miss is not.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: The cached item, or `nil` if it does not exist, is expired, or can no longer
    ///   be decoded.
    /// - Throws: An error if the lookup could not be completed.
    public func resource(for identifier: Item.ID) async throws -> Item? {
        try await database.resource(for: identifier)?.item
    }

    /// Clears all cached items from the underlying storage.
    ///
    /// Only files this cache wrote are deleted. The directory you nominated, any subfolder you
    /// nominated, anything else inside either of them, and the entries of any cache over a
    /// different item type, are left untouched.
    ///
    /// - Throws: An error if the storage could not be cleared.
    public func reset() async throws {
        try await database.removeAll()
    }

    /// Removes every expired entry this cache wrote, and reports how many were removed.
    ///
    /// Only entries inside this cache's own type folder are considered, so the sweep cannot reach
    /// another item type's entries, a file you placed there yourself, or anything written by an
    /// earlier layout. An entry is judged by the expiry it carries, not by whether its item still
    /// decodes, so an expired entry written by an earlier version of your `Codable` type is
    /// removed like any other. <doc:OnDiskFormat> says exactly what is and is not removed, and
    /// why.
    ///
    /// - Returns: The number of entries removed.
    /// - Throws: An error if the cache folder could not be created or listed, an entry could not
    ///   be read, or an expired entry could not be deleted. Entries removed before the fault stay
    ///   removed; the sweep is not transactional.
    @discardableResult
    public func removeExpired() async throws -> Int {
        try await database.removeExpired()
    }
}
