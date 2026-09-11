//
//  Database.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A cache-like database abstraction that provides access to a storage backend and resource lifecycle management.
///
/// `Database` defines a higher-level interface for managing `Resource`-wrapped items,
/// backed by a concrete implementation of ``Storage``. It provides lifecycle behaviours
/// such as stashing, fetching, and automatic expiration handling.
///
/// - Note: Resources that have expired are automatically removed during access.
protocol Database: ResourceProvider {

    /// The underlying storage provider used for storing resources.
    associatedtype Store: Storage

    /// The backing store containing cached or persisted resources.
    var storage: Store { get }
}

extension Database {

    /// Inserts a resource into the database.
    ///
    /// This operation delegates to the underlying storage's `insert` method.
    ///
    /// - Parameter resource: The resource to insert into the database.
    /// - Throws: An error if the underlying storage operation fails.
    func stash(_ resource: Store.Resource) throws {
        try storage.insert(resource)
    }

    /// Retrieves a resource for the given identifier, if available and not expired.
    ///
    /// If the resource exists but is expired, it is automatically removed and `nil` is returned.
    ///
    /// - Parameter identifier: The identifier of the resource to fetch.
    /// - Returns: A valid resource if found and not expired, or `nil` otherwise.
    /// - Throws: An error if the storage operation fails.
    func resource(for identifier: Store.Item.ID) throws -> Store.Resource? {

        guard let resource = try storage.resource(for: identifier) else {
            return nil
        }

        if resource.isExpired {
            try storage.remove(for: identifier)
            return nil
        }

        return resource
    }

    /// Removes the resource held for the specified identifier, if there is one.
    ///
    /// The resource is not read first, so it is removed whether or not it has expired and
    /// whether or not its stored payload can still be decoded.
    ///
    /// - Parameter identifier: The identifier of the resource to remove.
    /// - Throws: An error if a resource is held and cannot be removed.
    func removeResource(for identifier: Store.Item.ID) throws {
        try storage.remove(for: identifier)
    }

    /// Removes all resources from the database.
    ///
    /// - Throws: An error if the storage cannot be cleared.
    func removeAll() throws {
        try storage.removeAll()
    }
}
