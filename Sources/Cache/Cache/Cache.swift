//
//  Cache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A protocol that defines a generic, storable cache for identifiable items.
///
/// `Cache` provides an abstraction over asynchronous, expiry-aware caches that support
/// insert, lookup, and removal operations for items identified by a unique ID. It is
/// suitable for both in-memory and persistent cache implementations.
///
/// Conforming types are responsible for managing item expiry and storage lifecycle,
/// and must not return expired items from the `resource(for:)` method.
public protocol Cache<Item>: Sendable {
    
    /// The type of item being stored in the cache.
    associatedtype Item: Identifiable

    /// Inserts or updates a cache entry for the given item, using the provided expiry duration.
    ///
    /// - Parameters:
    ///   - item: The item to be stored in the cache.
    ///   - duration: The expiry policy defining how long the item remains valid.
    /// - Throws: An error if the item could not be cached.
    func stash(_ item: Item, duration: Expiry) async throws

    /// Removes a cached item using its identifier.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: An error if the item could not be removed.
    func removeResource(for identifier: Item.ID) async throws

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: The cached item if it exists and is still valid, or `nil` if not found or expired.
    /// - Throws: An error if the lookup fails.
    func resource(for identifier: Item.ID) async throws -> Item?

    /// Clears all items from the cache.
    ///
    /// This method removes all cached entries, regardless of expiry status.
    ///
    /// - Throws: An error if the reset operation fails.
    func reset() async throws
}
