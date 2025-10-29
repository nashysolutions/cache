//
//  ResourceProvider.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

/// A protocol for types that provide access to `Resource`-wrapped items, including lifecycle operations like insert, fetch, and delete.
///
/// `ResourceProvider` defines a common interface for interacting with a resource store,
/// supporting operations such as saving, loading, and purging resources based on their identifier.
///
/// Conforming types are expected to handle expired resources gracefully during lookup or removal.
protocol ResourceProvider {
    
    /// The underlying identifiable item type associated with the stored resource.
    associatedtype Item: Identifiable

    /// The type of resource managed by the provider.
    ///
    /// Must conform to ``ExpiringResource`` and associate with the `Item` type.
    associatedtype StoredResource: ExpiringResource where StoredResource.Item == Item

    /// Inserts or replaces a resource in the store.
    ///
    /// - Parameter resource: The resource to save.
    /// - Throws: An error if the operation fails (e.g. due to encoding, storage, or access issues).
    func stash(_ resource: StoredResource) throws

    /// Retrieves a resource for the given identifier, if it exists and is not expired.
    ///
    /// - Parameter identifier: The identifier of the item to load.
    /// - Returns: The valid resource if found, or `nil` if no resource exists or it is expired.
    /// - Throws: An error if the operation fails (e.g. due to decoding or file access errors).
    func resource(for identifier: Item.ID) throws -> StoredResource?

    /// Removes a resource by identifier, if it exists.
    ///
    /// - Parameter identifier: The identifier of the resource to remove.
    /// - Throws: An error if the deletion fails.
    func removeResource(for identifier: Item.ID) throws

    /// Removes all resources from the store.
    ///
    /// - Throws: An error if the operation fails or the store cannot be cleared.
    func removeAll() throws
}
