//
//  Cache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A protocol that defines a generic, storable cache for identifiable items with support for expiry and automatic reset.
///
/// Types conforming to `Cache` are expected to provide an asynchronous interface for storing,
/// retrieving, and removing items, as well as resetting the entire cache. Items are associated with an expiry,
/// and a maximum capacity can be configured to limit resource usage.
public protocol Cache {
    
    /// The type of item being stored in the cache.
    associatedtype Item: Identifiable

    /// Stashes an item into the cache with an associated expiry duration.
    ///
    /// - Parameters:
    ///   - item: The item to be cached.
    ///   - duration: The expiry duration for the item. Once expired, the item may be removed automatically.
    func stash(_ item: Item, duration: Expiry) async throws

    /// Removes a cached item using its identifier.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    func removeResource(for identifier: Item.ID) async throws

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: The cached item if it exists and is valid, or `nil` if not found or expired.
    func resource(for identifier: Item.ID) async throws -> Item?

    /// Clears all items from the cache.
    ///
    /// This method removes all currently cached items regardless of their expiry status.
    func reset() async throws
}
