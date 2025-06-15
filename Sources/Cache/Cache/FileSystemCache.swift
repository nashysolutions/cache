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
/// - Note: This cache uses the identifier of each item as its filename.
public struct FileSystemCache<Item: Identifiable & Codable>: DatabaseBackedCache {
    
    /// The backing file system–based database.
    let database: FileSystemDatabase<Item>
    
    /// Creates a new file system–backed cache.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The root directory in which resources will be stored.
    ///   - subfolder: An optional subfolder name used to scope the cache contents. Defaults to `nil`.
    public init(
        _ fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil
    ) {
        database = FileSystemDatabase<Item>(fileSystemDirectory: fileSystemDirectory, subfolder: subfolder)
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
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: An error if the resource could not be deleted.
    public func removeResource(for identifier: Item.ID) async throws {
        try await database.removeResource(for: identifier)
    }

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: The cached item, or `nil` if it does not exist or is expired.
    /// - Throws: An error if the item could not be loaded or decoded.
    public func resource(for identifier: Item.ID) async throws -> Item? {
        try await database.resource(for: identifier)?.item
    }

    /// Clears all cached items from the underlying storage.
    ///
    /// - Throws: An error if the storage could not be cleared.
    public func reset() async throws {
        try await database.removeAll()
    }
}
