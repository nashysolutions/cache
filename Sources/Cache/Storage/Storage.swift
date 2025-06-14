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
    
    associatedtype Item: Identifiable
    associatedtype Resource: ExpiringResource where Resource.Item == Item

    /// The total number of stored resources.
    var count: Int { get }

    func insert(_ resource: Resource) throws
    func remove(_ resource: Resource) throws
    func removeAll() throws

    func first(where: (Resource) -> Bool) throws -> Resource?
}

protocol CodableStorage: Storage where Item: Codable, Resource: Codable {}
