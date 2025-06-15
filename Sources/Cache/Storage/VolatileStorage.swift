//
//  VolatileStorage.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

@ResourceStorageActor
final class VolatileStorage<Item: Identifiable>: Storage {
    
    typealias StoredResource = Resource<Item>

    private var storage = Set<StoredResource>()

    func insert(_ resource: StoredResource) {
        storage.update(with: resource)
    }

    func remove(_ resource: StoredResource) {
        storage.remove(resource)
    }

    func removeAll() {
        storage.removeAll()
    }
    
    func resource(for identifier: Item.ID) throws -> StoredResource? {
        let predicate: (StoredResource) -> Bool = { $0.identifier == identifier }
        return storage.first(where: predicate)
    }
}
