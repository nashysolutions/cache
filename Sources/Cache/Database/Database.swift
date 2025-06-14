//
//  Database.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A cache-like database abstraction that provides access to a storage backend and resource lifecycle management.
///
/// Types conforming to `Database` must provide a `Storage`-backed store and implement
/// a mechanism to clear storage when a resource limit is reached.
@ResourceStorageActor
protocol Database: ResourceProvider {
    
    /// The underlying storage provider used for storing resources.
    associatedtype Store: Storage

    /// The backing store containing cached or persisted resources.
    var storage: Store { get }

    /// Clears the storage if the number of resources exceeds a configured threshold.
    ///
    /// Implementations typically use `recordCountMaximum` to determine when to purge the store.
    func clearStorageIfNecessary()
}

extension Database {
    
    /// Stashes a resource into storage and purges older resources if needed.
    ///
    /// If the maximum resource count is reached, `clearStorageIfNecessary()` is called to reset the store.
    /// - Parameter resource: The resource to stash.
    func stash(_ resource: Resource<Store.Item>) {
        clearStorageIfNecessary()
        storage.insert(resource)
    }
    
    /// Checks if the storage exceeds its configured maximum and clears it if so.
    ///
    /// This is typically called before inserting a new resource to ensure the cache remains within bounds.
    func clearStorageIfNecessary() {
        if storage.count >= recordCountMaximum {
            removeAll()
        }
    }

    /// Returns the resource for a given identifier, if it exists and is not expired.
    ///
    /// Expired resources are removed automatically.
    /// - Parameter identifier: The unique identifier of the item to retrieve.
    /// - Returns: A valid, non-expired resource if available; otherwise, `nil`.
    func resource(for identifier: Store.Item.ID) -> Resource<Store.Item>? {
        let predicate: (Resource<Store.Item>) -> Bool = {
            $0.identifier == identifier
        }

        guard let resource = storage.first(where: predicate) else {
            return nil
        }

        guard !resource.isExpired else {
            storage.remove(resource)
            return nil
        }

        return resource
    }

    /// Removes the resource with the given identifier, if it exists.
    ///
    /// - Parameter identifier: The identifier of the resource to remove.
    func removeResource(for identifier: Store.Item.ID) {
        if let resource = resource(for: identifier) {
            storage.remove(resource)
        }
    }

    /// Removes all resources from the storage.
    func removeAll() {
        storage.removeAll()
    }
}
