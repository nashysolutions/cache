//
//  VolatileStorage.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// An in-memory, non-persistent implementation of `StorageProvider` using a `Set`-backed collection.
///
/// `VolatileStorage` is intended for temporary resource caching that does not persist beyond the lifetime
/// of the application session. It supports fast insertions, removals, and lookups, but all data is lost on reset or shutdown.
@ResourceStorageActor
final class VolatileStorage<Item: Identifiable>: Storage {

    /// The internal storage set containing all cached resources.
    private var storage = Set<Resource<Item>>()

    /// The number of resources currently held in memory.
    ///
    /// This includes all resources, regardless of their expiry status.
    var count: Int {
        storage.count
    }

    /// Inserts or updates a resource in the in-memory store.
    ///
    /// If a resource with the same identifier already exists, it is replaced.
    ///
    /// - Parameter resource: The resource to insert.
    func insert(_ resource: Resource<Item>) {
        storage.update(with: resource)
    }

    /// Removes the specified resource from the in-memory store.
    ///
    /// If the resource does not exist, the operation has no effect.
    ///
    /// - Parameter resource: The resource to remove.
    func remove(_ resource: Resource<Item>) {
        storage.remove(resource)
    }

    /// Clears all resources from the in-memory store.
    ///
    /// All cached entries are discarded immediately.
    func removeAll() {
        storage.removeAll()
    }

    /// Finds the first resource that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes a resource and returns `true` if it matches.
    /// - Returns: The first matching resource if found; otherwise, `nil`.
    func first(where predicate: (Resource<Item>) -> Bool) -> Resource<Item>? {
        storage.first(where: predicate)
    }
}
