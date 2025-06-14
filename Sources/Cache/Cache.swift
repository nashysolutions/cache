//
//  Cache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A lightweight, in-memory cache for identifiable items with support for expiry and automatic purging.
///
/// `Cache` wraps a `VolatileDatabase` and allows items to be stashed with a defined lifespan. Once the
/// configured maximum number of records is reached, the cache resets itself automatically.
///
/// This type is suitable for short-lived or non-persistent caching scenarios.
public struct Cache<Item: Identifiable> {
    
    /// The underlying volatile, in-memory database.
    private let database: VolatileDatabase<Item>

    /// Creates a new cache instance with an optional maximum capacity.
    ///
    /// Once the number of stored items reaches `maxSize`, the cache will automatically reset.
    ///
    /// - Parameter maxSize: The maximum number of items to store before purging.
    public init(maxSize count: UInt = 100) {
        database = VolatileDatabase<Item>(recordCountMaximum: count)
    }

    /// Stashes an item in the cache with a given expiry duration.
    ///
    /// If an item with the same identifier already exists, it will be replaced.
    /// To extend the expiry of an existing item, remove it and stash it again.
    ///
    /// - Parameters:
    ///   - item: The item to cache.
    ///   - duration: The duration the item should remain valid.
    public func stash(_ item: Item, duration: Expiry) async {
        let resource = Resource<Item>(item: item, expiry: duration.date)
        await database.stash(resource)
    }

    /// Removes an item from the cache by its identifier, if present.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    public func removeResource(for identifier: Item.ID) async {
        await database.removeResource(for: identifier)
    }

    /// Retrieves an item from the cache by its identifier, if present and not expired.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: The item if found and not expired, or `nil` otherwise.
    public func resource(for identifier: Item.ID) async -> Item? {
        await database.resource(for: identifier)?.item
    }

    /// Clears all items from the cache.
    ///
    /// This operation discards all stored and stashed data.
    public func reset() async {
        await database.removeAll()
    }
}
