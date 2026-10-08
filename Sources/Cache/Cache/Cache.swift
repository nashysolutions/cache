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
/// and must not return expired items from the `item(for:)` method.
///
/// A conformance implements every requirement that is not deprecated. The requirements that 6.0.0
/// named differently are still declared, deprecated, so that code written against 6.0.0 keeps
/// compiling. Each is satisfied by a default that calls its new name, so a new conformance need
/// not implement them.
public protocol Cache<Item>: Sendable {

    /// The type of item being stored in the cache.
    ///
    /// Both the item and its identifier must be `Sendable`, because every requirement below is
    /// asynchronous and nonisolated: a caller isolated to an actor sends any item or identifier
    /// it passes out of that isolation. Stating the bound here, and not only on each conformer,
    /// is what lets generic code over `Cache` make those calls from an actor.
    associatedtype Item: Identifiable & Sendable where Item.ID: Sendable

    /// Stores an item under its identifier, replacing any entry the cache already holds for that
    /// identifier, expiry included.
    ///
    /// - Parameters:
    ///   - item: The item to be stored in the cache.
    ///   - expiry: When the entry stops being served.
    /// - Throws: An error if the item could not be cached.
    func setItem(_ item: Item, expiry: Expiry) async throws

    /// Removes a cached item using its identifier.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: An error if the item could not be removed.
    func removeItem(for identifier: Item.ID) async throws

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: The cached item if it exists and is still valid, or `nil` if not found or expired.
    /// - Throws: An error if the lookup fails.
    func item(for identifier: Item.ID) async throws -> Item?

    /// Clears all items from the cache.
    ///
    /// This method removes all cached entries, regardless of expiry status.
    ///
    /// - Throws: An error if the entries could not be removed.
    func removeAll() async throws

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

    // The 6.0.0 names. Each stays a requirement so that a conformance written against 6.0.0,
    // which implements these and not the names above, is still reached through the protocol. Each
    // is deprecated as a requirement, not only as a default, because a requirement that is not
    // deprecated makes the compiler warn every conformance that implements only the new name, and
    // that warning could not be silenced. The defaults in both directions are in Deprecated.swift.
    // These requirements, and those defaults, are removed in 8.0.0.

    /// Stores an item under its identifier, replacing any entry already held for it.
    ///
    /// - Parameters:
    ///   - item: The item to be stored in the cache.
    ///   - duration: When the entry stops being served.
    /// - Throws: An error if the item could not be cached.
    @available(*, deprecated, renamed: "setItem(_:expiry:)", message: "Use setItem(_:expiry:). stash(_:duration:) is removed in 8.0.0.")
    func stash(_ item: Item, duration: Expiry) async throws

    /// Removes a cached item using its identifier.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: An error if the item could not be removed.
    @available(*, deprecated, renamed: "removeItem(for:)", message: "Use removeItem(for:). removeResource(for:) is removed in 8.0.0.")
    func removeResource(for identifier: Item.ID) async throws

    /// Retrieves a cached item by its identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: The cached item if it exists and is still valid, or `nil` if not found or expired.
    /// - Throws: An error if the lookup fails.
    @available(*, deprecated, renamed: "item(for:)", message: "Use item(for:). resource(for:) is removed in 8.0.0.")
    func resource(for identifier: Item.ID) async throws -> Item?

    /// Clears all items from the cache.
    ///
    /// - Throws: An error if the entries could not be removed.
    @available(*, deprecated, renamed: "removeAll()", message: "Use removeAll(). reset() is removed in 8.0.0.")
    func reset() async throws
}
