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

    var count: Int {
        storage.count
    }

    func insert(_ resource: StoredResource) {
        storage.update(with: resource)
    }

    func remove(_ resource: StoredResource) {
        storage.remove(resource)
    }

    func removeAll() {
        storage.removeAll()
    }

    func first(where predicate: (StoredResource) -> Bool) -> StoredResource? {
        storage.first(where: predicate)
    }
}
