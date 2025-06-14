//
//  Storage.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

/// A type that provides basic resource storage capabilities, such as insertion, removal, and lookup.
///
/// `Storage` defines a minimal interface for working with collections of `Resource` values
/// tied to identifiable items. Implementations may be in-memory, file-based, or remote,
/// and are expected to manage expiry and identity via the associated `Item` type.
@ResourceStorageActor
protocol Storage {
    
    /// The type of item stored in the resource.
    associatedtype Item: Identifiable

    /// The total number of stored resources.
    ///
    /// This count may include expired items unless explicitly cleaned.
    var count: Int { get }

    /// Inserts or replaces a resource in storage.
    ///
    /// If a resource with the same identifier already exists, it is updated with the new one.
    ///
    /// - Parameter resource: The resource to insert into storage.
    func insert(_ resource: Resource<Item>)

    /// Removes a specific resource from storage.
    ///
    /// - Parameter resource: The resource to remove. If it does not exist, this operation has no effect.
    func remove(_ resource: Resource<Item>)

    /// Clears all resources from storage.
    ///
    /// This operation removes all entries, regardless of expiry status.
    func removeAll()

    /// Finds the first resource that matches the given predicate.
    ///
    /// - Parameter where: A closure that evaluates whether a given resource matches the criteria.
    /// - Returns: The first matching resource if found; otherwise, `nil`.
    func first(where: (Resource<Item>) -> Bool) -> Resource<Item>?
}
