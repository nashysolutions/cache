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
    
    public init(
        _ fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil
    ) {
        database = FileSystemDatabase<Item>(fileSystemDirectory: fileSystemDirectory, subfolder: subfolder)
    }
    
    // Not supporting expiry for now
//    public func stash(_ item: Item, duration: Expiry) async throws {
//        let resource = CodableResource(item: item, expiry: duration.date())
//        try await database.stash(resource)
//    }
    
    public func stash(_ item: Item) async throws {
        let resource = CodableResource(item: item, expiry: Date()) // expiry ignored
        try await database.stash(resource)
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
