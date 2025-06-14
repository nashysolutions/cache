//
//  FileSystemCache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

public struct FileSystemCache<Item: Identifiable & Codable>: DatabaseBackedCache {
    
    let database: FileSystemDatabase<Item>
    
    /// Creates a new volatile cache instance with an optional maximum size.
    ///
    /// - Parameter count: The maximum number of items allowed in the cache. When this limit is reached,
    ///   the backing database will reset, clearing all stored entries. The default is `100`.
    public init(
        _ fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil,
        maxSize count: UInt = 100
    ) {
        self.database = FileSystemDatabase<Item>(
            fileSystemDirectory: fileSystemDirectory,
            subfolder: subfolder,
            recordCountMaximum: count
        )
    }
    
    public func stash(_ item: Item, duration: Expiry) async throws {
        let resource = CodableResource(item: item, expiry: duration.date)
        try await database.stash(resource) // Cannot convert value of type 'CodableResource<Item>' to expected argument type 'Resource<FileSystemDatabase<Item>.Store.Item>'
    }

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
