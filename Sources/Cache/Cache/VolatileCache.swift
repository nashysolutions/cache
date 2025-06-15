//
//  VolatileCache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A lightweight, in-memory cache implementation.
///
/// `VolatileCache` provides asynchronous, expiry-aware storage for identifiable items.
/// It wraps a ``VolatileDatabase`` and is suitable for storing non-persistent, runtime-only data.
///
/// Resources are automatically expired based on the provided ``Expiry`` and evicted
/// when the internal storage exceeds its configured maximum size.
///
/// - Note: This cache is entirely in-memory and will not retain data between app sessions.
public struct VolatileCache<Item: Identifiable>: DatabaseBackedCache {

    /// The backing volatile database used for storage.
    let database: VolatileDatabase<Item>
    
    /// Creates a new volatile cache instance.
    ///
    /// By default, it uses the `VolatileDatabase`'s default maximum record limit.
    public init() {
        database = VolatileDatabase<Item>()
    }

    /// Stashes an item in the cache with a given expiry duration.
    ///
    /// If the cache exceeds its record limit, older entries may be evicted.
    ///
    /// - Parameters:
    ///   - item: The item to store in the cache.
    ///   - duration: The expiry policy to use.
    /// - Throws: An error if the item could not be inserted.
    public func stash(_ item: Item, duration: Expiry) async throws {
        let resource = Resource<Item>(item: item, expiry: duration.date())
        try await database.stash(resource)
    }

    /// Removes a specific item from the cache, if present.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: An error if removal fails.
    public func removeResource(for identifier: Item.ID) async throws {
        try await database.removeResource(for: identifier)
    }

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: The cached item, or `nil` if it does not exist or is expired.
    /// - Throws: An error if the lookup fails.
    public func resource(for identifier: Item.ID) async throws -> Item? {
        try await database.resource(for: identifier)?.item
    }

    /// Clears all items from the cache.
    ///
    /// - Throws: An error if the reset operation fails.
    public func reset() async throws {
        try await database.removeAll()
    }
}
