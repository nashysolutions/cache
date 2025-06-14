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
    func clearStorageIfNecessary() throws
}

extension Database {
    
    func stash(_ resource: Store.Resource) throws {
        try clearStorageIfNecessary()
        try storage.insert(resource)
    }

    func clearStorageIfNecessary() throws {
        if storage.count >= recordCountMaximum {
            try removeAll()
        }
    }

    func resource(for identifier: Store.Item.ID) throws -> Store.Resource? {
        let predicate: (Store.Resource) -> Bool = {
            $0.identifier == identifier
        }

        guard let resource = try storage.first(where: predicate) else {
            return nil
        }

        guard !resource.isExpired else {
            try storage.remove(resource)
            return nil
        }

        return resource
    }

    func removeResource(for identifier: Store.Item.ID) throws {
        if let resource = try resource(for: identifier) {
            try storage.remove(resource)
        }
    }

    func removeAll() throws {
        try storage.removeAll()
    }
}
