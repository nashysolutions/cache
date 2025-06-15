//
//  VolatileCache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A lightweight, in-memory cache implementation.
///
/// Provides asynchronous, expiry-aware storage for identifiable
/// items. It automatically clears its contents when the configured maximum record
/// count is reached. This cache is non-persistent and suitable for temporary,
/// runtime-only data.
public struct VolatileCache<Item: Identifiable>: DatabaseBackedCache {

    let database: VolatileDatabase<Item>
    
    /// Creates a new volatile cache instance with an optional maximum size.
    public init() {
        database = VolatileDatabase<Item>()
    }
    
    public func stash(_ item: Item) async throws {
        let resource = Resource<Item>(item: item, expiry: Date()) // expiry ignored for now
        try await database.stash(resource)
    }
    
//    public func stash(_ item: Item, duration: Expiry) async throws {
//        let resource = Resource<Item>(item: item, expiry: duration.date())
//        try await database.stash(resource)
//    }

    public func removeResource(for identifier: Item.ID) async throws {
        try await database.removeResource(for: identifier)
    }

    public func resource(for identifier: Item.ID) async throws -> Item? {
        try await database.resource(for: identifier)?.item
    }

    public func reset() async throws {
        try await database.removeAll()
    }
}
