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
/// a mechanism to clear storage.
@ResourceStorageActor
protocol Database: ResourceProvider {
    
    /// The underlying storage provider used for storing resources.
    associatedtype Store: Storage

    /// The backing store containing cached or persisted resources.
    var storage: Store { get }
}

extension Database {
    
    func stash(_ resource: Store.Resource) throws {
        try storage.insert(resource)
    }

    func resource(for identifier: Store.Item.ID) throws -> Store.Resource? {
        
        guard let resource = try storage.resource(for: identifier) else {
            return nil
        }
        
        // not supporting this right now. see `ExpiringResource`
//        guard !resource.isExpired else {
//            try storage.remove(resource)
//            return nil
//        }

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
