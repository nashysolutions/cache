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
/// `FileSystemCache` provides expiry-aware, asynchronous caching of resources that are stored
/// on disk using a ``FileSystemDatabase``. It is suitable for use cases where data must be retained
/// across app launches or shared between components.
///
/// Resources are persisted as `CodableResource` values, allowing for serialisation and deserialisation
/// using the file system.
///
/// Entries are written into a versioned folder below the directory you nominate, and never
/// directly into it. The cache therefore only ever deletes files it wrote itself, and it never
/// deletes a directory. See <doc:OnDiskFormat> for the layout and for what happens to entries
/// written by an earlier version.
public struct FileSystemCache<Item: Identifiable & Codable & Sendable>: DatabaseBackedCache where Item.ID: Sendable & LosslessStringConvertible {

    /// The backing file system–based database.
    let database: FileSystemDatabase<Item>

    /// Creates a new file system–backed cache.
    ///
    /// Favors the hash-based filename strategy and enforces that `Item.ID`
    /// conforms to `LosslessStringConvertible` to maintain compatibility with
    /// public API that relies on lossless identifiers while still using hashed
    /// filenames for robustness.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The root directory in which resources will be stored.
    ///   - subfolder: An optional subfolder name used to scope the cache contents. Defaults to `nil`.
    public init(
        _ fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil
    ) where Item.ID: LosslessStringConvertible {
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
        let resource = CodableResource(item: item, expiry: duration.date())
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
    /// An error means the lookup could not be completed, such as a failure to read an entry that
    /// is there. That is worth catching; a miss is not.
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
    /// nominated, and anything else inside either of them, are left untouched.
    ///
    /// - Throws: An error if the storage could not be cleared.
    public func reset() async throws {
        try await database.removeAll()
    }
}
