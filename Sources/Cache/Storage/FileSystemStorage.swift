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
import CryptoKit

/// A resource storage backend that persists data to the local file system.
///
/// `FileSystemStorage` provides a `CodableStorage`-conforming implementation that saves
/// and retrieves `CodableResource` instances using a structured file system directory and
/// optional subfolder path.
///
/// Entries are written into a versioned folder below the configured directory and carry a
/// recognisable extension, so this storage can identify its own files. See ``FileSystemLayout``
/// for the shape and for why it is versioned.
///
/// - Note: This storage requires items to conform to both `Identifiable` and `Codable`.
final class FileSystemStorage<Item: Identifiable & Codable & Sendable>: CodableStorage  where Item.ID: LosslessStringConvertible {

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

    /// Whether this instance has already looked for entries left behind by an earlier layout.
    ///
    /// The sweep is idempotent, so running it once per instance is enough; the flag only keeps
    /// it off the path of every subsequent operation.
    private var hasSweptUnversionedLayout = false

    /// Creates a new file system-backed storage instance with a filename strategy.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The base file system directory.
    ///   - subfolder: An optional subfolder path within the base directory.
    public init(
        fileSystemDirectory: FileSystemDirectory,
        subfolder: String?
    ) {
        self.fileSystemDirectory = fileSystemDirectory
        self.subfolder = subfolder
    }

    /// Returns the underlying file system store used for saving, loading, and deleting resources.
    ///
    /// The store is scoped to the versioned folder described by ``FileSystemLayout``, so nothing
    /// this storage saves, loads or deletes ever sits directly in the consumer's own directory.
    ///
    /// - Throws: An error if the store could not be created.
    private var store: any FileSystemOperations {
        get throws {
            // The unversioned store is made first for two reasons. It is the directory the sweep
            // runs in, and creating it as a separate step means each level of the path is created
            // one at a time, so an agent whose `createDirectory` does not create intermediate
            // directories continues to work.
            let unversionedStore = try fileSystemResourceClient.makeStore(
                fileSystemDirectory,
                subfolder
            )

            if hasSweptUnversionedLayout == false {
                hasSweptUnversionedLayout = true
                sweepUnversionedLayout(in: unversionedStore)
            }

            return try fileSystemResourceClient.makeStore(
                fileSystemDirectory,
                FileSystemLayout.versionedSubfolder(below: subfolder)
            )
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

    /// Removes every entry this storage wrote.
    ///
    /// Only files matching the current layout are deleted. The enclosing folder, and anything
    /// else inside it, is left alone, including files a consumer or another component put there.
    ///
    /// - Throws: An error if the folder could not be enumerated, or an entry could not be deleted.
    func removeAll() throws {
        try store.deleteFiles { entry in
            entry.value(\.isRegularFile) == true
            && FileSystemLayout.isEntryFilename(entry.url.lastPathComponent)
        }
    }

    /// Deletes entries left behind by a layout that predates ``FileSystemLayout/versionFolderName``.
    ///
    /// Those entries are unreachable: a lookup computes a different path, so they are never read,
    /// never expired and never removed, and they occupy the consumer's disk indefinitely. They sit
    /// directly in the directory the consumer nominated, which this package does not own, so a
    /// candidate is deleted only once its contents have been confirmed to be a cache record. A
    /// file that cannot be read, or that is too large to inspect, is left where it is.
    ///
    /// Failures are deliberately swallowed. This is housekeeping, and a directory that cannot be
    /// enumerated is a reason to skip the cleanup, not a reason for the cache itself to stop
    /// working.
    ///
    /// - Parameter store: A store scoped to the directory the earlier layout wrote into.
    private func sweepUnversionedLayout(in store: any FileSystemOperations) {

        guard let entries = try? store.contents(
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else {
            return
        }

        let decoder = JSONDecoder()
        var unversioned: Set<URL> = []

        for entry in entries {

            guard entry.value(\.isRegularFile) == true else {
                continue
            }

            guard let size = entry.value(\.fileSize),
                  size <= FileSystemLayout.unversionedInspectionByteLimit else {
                continue
            }

            guard let data = try? store.loadData(named: entry.url.lastPathComponent) else {
                continue
            }

            let record = try? decoder.decode(FileSystemLayout.UnversionedRecord.self, from: data)

            if record != nil {
                unversioned.insert(entry.url)
            }
        }

        guard unversioned.isEmpty == false else {
            return
        }

        _ = try? store.deleteFiles { entry in
            unversioned.contains(entry.url)
        }
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
    /// The hashed identifier carries the extension described by ``FileSystemLayout``, which is
    /// what makes an entry recognisable as one this package wrote.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: A string representing the filename.
    private func filename(for identifier: Item.ID) -> String {
        let identifierString = String(describing: identifier)
        return hash(identifierString) + "." + FileSystemLayout.entryFileExtension
    }

    /// Computes a filesystem-safe filename by hashing an identifier string.
    ///
    /// This function encodes the given `identifierString` as UTF-8, computes a
    /// SHA-256 digest using CryptoKit, and returns the lowercase hexadecimal
    /// representation. The result is stable for the same input and avoids
    /// characters that may be invalid in filenames across platforms.
    ///
    /// - Important: This is not intended for security-sensitive uses like
    ///   password hashing. It is used purely to derive a deterministic, compact
    ///   filename from an identifier.
    /// - Parameter identifierString: The textual representation of an item
    ///   identifier to hash.
    /// - Returns: A 64-character lowercase hex string of the SHA-256 digest.
    /// - Precondition: The identifier must be encodable as UTF-8. A failure
    ///   triggers a `preconditionFailure` because it indicates a programming
    ///   error upstream (e.g., constructing an invalid identifier string).
    private func hash(_ identifierString: String) -> String {
        guard let data = identifierString.data(using: .utf8) else {
            preconditionFailure(
                "Unable to UTF-8 encode identifier string: \(identifierString)"
            )
        }

        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
