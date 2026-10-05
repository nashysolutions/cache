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
/// It is suitable for storing non-persistent, runtime-only data.
///
/// Every entry carries an ``Expiry``, and an expired entry is never served. Nothing bounds the
/// cache and nothing evicts from it. An expired entry is removed when its identifier is next
/// looked up, or when ``removeExpired()`` is called. Until then, an entry that is never looked up
/// again stays in memory for as long as the cache lives.
///
/// - Note: This cache is entirely in-memory and will not retain data between app sessions.
public struct VolatileCache<Item: Identifiable & Sendable>: DatabaseBackedCache where Item.ID: Sendable {

    /// The backing volatile database used for storage.
    let database: VolatileDatabase<Item>

    /// Creates a new volatile cache instance.
    ///
    /// The cache starts empty and has no record limit: it holds every entry stashed in it until
    /// that entry is removed.
    public init() {
        database = VolatileDatabase<Item>()
    }

    /// Stashes an item in the cache with a given expiry duration.
    ///
    /// Stashing never removes another entry. An item stashed under an identifier the cache already
    /// holds replaces the entry for that identifier, expiry included.
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

    /// Removes every expired entry, and reports how many were removed.
    ///
    /// - Returns: The number of entries removed.
    /// - Throws: An error if the removal fails.
    @discardableResult
    public func removeExpired() async throws -> Int {
        try await database.removeExpired()
    }
}
