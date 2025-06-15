//
//  FileSystemStorage.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import FoundationDependencies
import Dependencies
import Files

@ResourceStorageActor
final class FileSystemStorage<Item: Identifiable & Codable>: CodableStorage {
    
    typealias StoredResource = CodableResource<Item>
    typealias Resource = StoredResource
    
    @Dependency(\.fileSystemResourceClient) var fileSystemResourceClient
    
    private let fileSystemDirectory: FileSystemDirectory
    private let subfolder: String?
    
    nonisolated init(fileSystemDirectory: FileSystemDirectory, subfolder: String?) {
        self.fileSystemDirectory = fileSystemDirectory
        self.subfolder = subfolder
    }
    
    private var store: any FileSystemOperations {
        get throws {
            try fileSystemResourceClient.makeStore(fileSystemDirectory, subfolder)
        }
    }

    func insert(_ resource: Resource) throws {
        try store.saveResource(resource, filename: filename(for: resource))
    }
    
    func remove(_ resource: Resource) throws {
        try store.deleteResource(filename: filename(for: resource))
    }
    
    func removeAll() throws {
        try store.folder.deleteIfExists(using: store.agent)
    }
    
    func resource(for identifier: Item.ID) throws -> StoredResource? {
        try store.loadResource(filename: filename(for: identifier))
    }
    
    private func filename(for resource: Resource) -> String {
        filename(for: resource.identifier)
    }
    
    private func filename(for identifier: Item.ID) -> String {
        String(describing: identifier)
    }
}
