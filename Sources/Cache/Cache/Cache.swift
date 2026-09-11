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

    /// Removes every expired entry, and reports how many were removed.
    ///
    /// Expiry is otherwise enforced on read: an expired entry is removed when its identifier is
    /// next looked up, so an identifier that is never looked up again leaves its entry in storage
    /// indefinitely. This is the explicit counterpart, for a consumer to call at a moment of their
    /// choosing, such as launch, sign-out, or a low-storage warning. Nothing calls it on the
    /// consumer's behalf, and no read or write triggers it.
    ///
    /// Every entry is judged against one instant, taken when the call begins, rather than against
    /// a clock read per entry. An entry that expires while the sweep is running is left for the
    /// next one, and two entries with the same expiry are never split by the sweep.
    ///
    /// The count is for a consumer that wants to log or test the sweep. One that calls it for
    /// the side effect alone may ignore it.
    ///
    /// - Returns: The number of entries removed.
    /// - Throws: An error if the entries could not be enumerated, or an expired entry could not
    ///   be removed.
    @discardableResult
    func removeExpired() async throws -> Int
}
