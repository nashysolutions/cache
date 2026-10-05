//
//  VolatileStorage.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// An in-memory, actor-isolated storage system for `Resource`-wrapped items.
///
/// `VolatileStorage` is a lightweight, non-persistent storage backend designed
/// for fast insertions, removals, and lookups of identifiable resources.
/// It is useful in scenarios like caching or temporary in-process storage.
///
/// - Note: This storage does **not** persist across app launches.
final class VolatileStorage<Item: Identifiable & Sendable>: Storage {

    /// The type of resource stored in memory.
    typealias StoredResource = Resource<Item>

    /// Every cached resource, keyed by the identifier of the item it wraps.
    ///
    /// This includes all resources, regardless of their expiry status. Keying by identifier makes
    /// lookup and removal by identifier constant time, and makes one entry per identifier a
    /// property of the structure itself rather than of how `Resource` defines equality.
    private var storage: [Item.ID: StoredResource] = [:]

    /// Inserts or updates a resource in the in-memory store.
    ///
    /// If a resource with the same identifier already exists, it is replaced.
    ///
    /// - Parameter resource: The resource to insert.
    func insert(_ resource: StoredResource) {
        storage[resource.identifier] = resource
    }

    /// Removes the resource held for the given identifier.
    ///
    /// If no resource is held for the identifier, the operation has no effect.
    ///
    /// - Parameter identifier: The identifier of the item whose resource should be removed.
    func remove(for identifier: Item.ID) {
        storage[identifier] = nil
    }

    /// Removes all resources currently stored in memory.
    ///
    /// This operation clears the entire cache.
    func removeAll() {
        storage.removeAll()
    }

    /// Retrieves a resource matching the given identifier, if present.
    ///
    /// - Parameter identifier: The identifier of the resource to retrieve.
    /// - Returns: The resource matching the identifier, or `nil` if not found.
    func resource(for identifier: Item.ID) -> StoredResource? {
        storage[identifier]
    }

    /// Removes every resource whose expiry precedes the given instant.
    ///
    /// - Parameter now: The instant to judge expiry against.
    /// - Returns: The number of resources removed.
    func removeExpired(asOf now: Date) -> Int {
        let countBeforeSweep = storage.count
        storage = storage.filter { !$0.value.isExpired(asOf: now) }
        return countBeforeSweep - storage.count
    }
}
