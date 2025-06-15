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

/// A resource storage backend that persists data to the local file system.
///
/// `FileSystemStorage` provides a `CodableStorage`-conforming implementation that saves
/// and retrieves `CodableResource` instances using a structured file system directory and
/// optional subfolder path.
///
/// This is a concurrency-safe, actor-isolated implementation using ``ResourceStorageActor``.
///
/// - Note: This storage requires items to conform to both `Identifiable` and `Codable`.
@ResourceStorageActor
final class FileSystemStorage<Item: Identifiable & Codable>: CodableStorage {
    
    /// The stored resource type used by this storage.
    typealias StoredResource = CodableResource<Item>
    
    /// The resource type exposed through the `Storage` protocol.
    typealias Resource = StoredResource

    /// The file system resource client used to interact with the underlying storage.
    @Dependency(\.fileSystemResourceClient) var fileSystemResourceClient
    
    /// The base directory where resources will be stored.
    private let fileSystemDirectory: FileSystemDirectory
    
    /// An optional subfolder under the base directory.
    ///
    /// If specified, all resources will be scoped to this subfolder.
    private let subfolder: String?
    
    /// Creates a new file system-backed storage instance.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The base file system directory.
    ///   - subfolder: An optional subfolder path within the base directory.
    nonisolated init(fileSystemDirectory: FileSystemDirectory, subfolder: String?) {
        self.fileSystemDirectory = fileSystemDirectory
        self.subfolder = subfolder
    }
    
    /// Returns the underlying file system store used for saving, loading, and deleting resources.
    ///
    /// - Throws: An error if the store could not be created.
    private var store: any FileSystemOperations {
        get throws {
            try fileSystemResourceClient.makeStore(fileSystemDirectory, subfolder)
        }
    }

    /// Inserts a resource into the file system.
    ///
    /// - Parameter resource: The resource to insert.
    /// - Throws: An error if the resource could not be written to disk.
    func insert(_ resource: Resource) throws {
        try store.saveResource(resource, filename: filename(for: resource))
    }
    
    /// Removes a specific resource from the file system.
    ///
    /// - Parameter resource: The resource to remove.
    /// - Throws: An error if the resource could not be deleted.
    func remove(_ resource: Resource) throws {
        try store.deleteResource(filename: filename(for: resource))
    }
    
    /// Removes all stored resources by deleting the entire folder.
    ///
    /// - Throws: An error if the folder could not be deleted.
    func removeAll() throws {
        try store.folder.deleteIfExists(using: store.agent)
    }
    
    /// Retrieves a resource by its identifier, if one exists on disk.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: A `CodableResource` if one is found, or `nil` if not.
    /// - Throws: An error if the resource could not be read or decoded.
    func resource(for identifier: Item.ID) throws -> StoredResource? {
        try store.loadResource(filename: filename(for: identifier))
    }
    
    /// Constructs a filename from the given resource.
    ///
    /// - Parameter resource: The resource whose identifier is used as the filename.
    /// - Returns: A string suitable for use as a filename.
    private func filename(for resource: Resource) -> String {
        filename(for: resource.identifier)
    }
    
    /// Constructs a filename from the given identifier.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: A string representing the filename.
    private func filename(for identifier: Item.ID) -> String {
        String(describing: identifier)
    }
}
