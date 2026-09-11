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

    /// Removes the resource held for the given identifier, if there is one.
    ///
    /// Removal is keyed by identifier rather than by resource so that an entry can be removed
    /// without first being read. A backend that has to read a resource in order to remove it
    /// cannot remove one it can no longer read, which leaves a stored payload that has stopped
    /// decoding stuck where it is.
    ///
    /// - Parameter identifier: The identifier of the item whose resource should be removed.
    /// - Throws: An error if a resource is held and cannot be removed. An identifier that holds
    ///   no resource is not an error.
    func remove(for identifier: Item.ID) throws

    /// Removes all resources from the storage.
    ///
    /// - Throws: An error if the storage could not be cleared.
    func removeAll() throws

    /// Retrieves a resource by its associated identifier.
    ///
    /// An identifier that holds no resource is not a failure, and neither is one whose stored
    /// payload can no longer be served. Both report `nil`. An error is reserved for a lookup
    /// that could not be completed, such as a permissions failure, which a caller needs to be
    /// able to tell apart from an ordinary absence.
    ///
    /// - Parameter identifier: The identifier of the item to fetch.
    /// - Returns: The resource if one is held and can be served, or `nil` if not.
    /// - Throws: An error if the lookup operation fails.
    func resource(for identifier: Item.ID) throws -> Resource?
}
