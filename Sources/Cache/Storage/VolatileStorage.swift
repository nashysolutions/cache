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
/// All operations are performed within the global `ResourceStorageActor` to ensure concurrency safety.
///
/// - Note: This storage does **not** persist across app launches.
@ResourceStorageActor
final class VolatileStorage<Item: Identifiable>: Storage {
    
    /// The type of resource stored in memory.
    typealias StoredResource = Resource<Item>

    /// The internal storage set containing all cached resources.
    ///
    /// This includes all resources, regardless of their expiry status.
    private var storage = Set<StoredResource>()

    /// Inserts or updates a resource in the in-memory store.
    ///
    /// If a resource with the same identifier already exists, it is replaced.
    ///
    /// - Parameter resource: The resource to insert.
    func insert(_ resource: StoredResource) {
        storage.update(with: resource)
    }

    /// Removes the specified resource from the in-memory store.
    ///
    /// If the resource does not exist, the operation has no effect.
    ///
    /// - Parameter resource: The resource to remove.
    func remove(_ resource: StoredResource) {
        storage.remove(resource)
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
    /// - Throws: Rethrows any errors thrown during lookup (currently unused but
    ///   supports compatibility with throwing storage protocols).
    func resource(for identifier: Item.ID) throws -> StoredResource? {
        let predicate: (StoredResource) -> Bool = { $0.identifier == identifier }
        return storage.first(where: predicate)
    }
}
