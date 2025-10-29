//
//  Storage.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

/// A type that provides basic resource storage capabilities, such as insertion, removal, and lookup.
///
/// `Storage` defines a minimal interface for managing `Resource` values associated with identifiable items.
/// It is intended to be implemented by concrete types that store resources in memory, on disk, or via a remote backend.
///
/// - Note: All conforming types must implement identity-based lookups and respect the identity of `Item`.
protocol Storage {
    
    /// The type of items managed by the resource.
    associatedtype Item: Identifiable

    /// The resource type stored in this storage.
    ///
    /// Must conform to ``ExpiringResource`` and be associated with the `Item` type.
    associatedtype Resource: ExpiringResource where Resource.Item == Item

    /// Inserts a resource into storage, replacing any existing resource with the same identity.
    ///
    /// - Parameter resource: The resource to insert.
    /// - Throws: An error if the insertion fails (e.g., due to write failure or invalid state).
    func insert(_ resource: Resource) throws

    /// Removes the specified resource from storage.
    ///
    /// - Parameter resource: The resource to remove.
    /// - Throws: An error if removal fails.
    func remove(_ resource: Resource) throws

    /// Removes all resources from the storage.
    ///
    /// - Throws: An error if the storage could not be cleared.
    func removeAll() throws

    /// Retrieves a resource by its associated identifier.
    ///
    /// - Parameter identifier: The identifier of the item to fetch.
    /// - Returns: The resource if found, or `nil` if no matching resource exists.
    /// - Throws: An error if the lookup operation fails.
    func resource(for identifier: Item.ID) throws -> Resource?
}
