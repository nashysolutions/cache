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

    @Dependency(\.fileSystemClient) var fileSystemClient

    private let fileSystemDirectory: FileSystemDirectory
    private let subfolder: String?

    nonisolated init(fileSystemDirectory: FileSystemDirectory, subfolder: String?) {
        self.fileSystemDirectory = fileSystemDirectory
        self.subfolder = subfolder
    }

    var count: Int {
        fatalError()
//        let store = try? fileSystemClient.makeStore(fileSystemDirectory, subfolder)
//        return store?.resourceCount() ?? 0
    }

    func insert(_ resource: Resource) throws {
        let store = try fileSystemClient.makeStore(fileSystemDirectory, subfolder)
        let filename = String(describing: resource.identifier)
        try store.saveResource(resource, filename: filename)
    }

    func remove(_ resource: Resource) throws {
        let store = try fileSystemClient.makeStore(fileSystemDirectory, subfolder)
        let filename = String(describing: resource.identifier)
        try store.deleteResource(filename: filename)
    }

    func removeAll() throws {
        fatalError()
//        let store = try fileSystemClient.makeStore(fileSystemDirectory, subfolder)
//        try store.deleteAllResources()
    }

    func first(where predicate: (Resource) -> Bool) throws -> Resource? {
        fatalError()
//        let store = try fileSystemClient.makeStore(fileSystemDirectory, subfolder)
//        let all = try store.loadAllResources(Resource.self)
//        return all.first(where: predicate)
    }
}
