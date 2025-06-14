//
//  ResourceProvider.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

@ResourceStorageActor
protocol ResourceProvider {
    
    associatedtype Item: Identifiable
    associatedtype StoredResource: ExpiringResource where StoredResource.Item == Item

    /// The maximum number of items allowed in the resource store.
    var recordCountMaximum: UInt { get }

    /// Inserts or replaces a resource.
    func stash(_ resource: StoredResource) throws

    /// Returns a non-expired resource for the given identifier.
    func resource(for identifier: Item.ID) throws -> StoredResource?

    /// Removes a resource by identifier, if it exists.
    func removeResource(for identifier: Item.ID) throws

    /// Removes all resources from the store.
    func removeAll() throws
}
