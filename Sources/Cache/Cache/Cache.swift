//
//  Cache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A protocol that defines a generic, storable cache for identifiable items.
///
/// Types conforming to `Cache` are expected to provide an asynchronous interface for storing,
/// retrieving, and removing items, as well as resetting the entire cache.
public protocol Cache {
    
    /// The type of item being stored in the cache.
    associatedtype Item: Identifiable

    /// Stashes an item into the cache.
    ///
    /// - Parameters:
    ///   - item: The item to be cached.
    func stash(_ item: Item) async throws
//    func stash(_ item: Item, duration: Expiry) async throws

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
