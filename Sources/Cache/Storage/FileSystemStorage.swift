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
            // The enclosing folder is made as a separate step so that each level of the path is
            // created one at a time. An agent whose `createDirectory` does not create intermediate
            // directories would otherwise fail to create the versioned folder below it.
            _ = try fileSystemResourceClient.makeStore(
                fileSystemDirectory,
                subfolder
            )

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

    /// Removes the entry held for the given identifier, if there is one.
    ///
    /// The entry is deleted by the filename its identifier derives, so it is never read first.
    /// An entry whose payload no longer decodes is therefore removed exactly like any other,
    /// rather than being stuck on disk because reading it is what fails.
    ///
    /// The existence check is what keeps an absent entry separate from a present one that cannot
    /// be deleted: `deleteResource(filename:)` reports both as the same error.
    ///
    /// - Parameter identifier: The identifier of the item whose entry should be removed.
    /// - Throws: An error if an entry is present and could not be deleted. An identifier with no
    ///   entry on disk is not an error.
    func remove(for identifier: Item.ID) throws {

        let store = try store
        let name = filename(for: identifier)

        guard store.folder.resource(filename: name).exists(using: store.agent) else {
            return
        }

        try store.deleteResource(filename: name)
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

    /// Retrieves the entry held for the given identifier, if one can be served.
    ///
    /// Three outcomes are kept apart, because a caller needs them apart:
    ///
    /// - **No entry on disk.** Reports `nil`. This is the ordinary state of every identifier a
    ///   consumer has not stashed, including all of them before the first stash on a fresh
    ///   install, so it is not a failure and must not be reported as one.
    /// - **An entry that does not decode.** Reports `nil`, and deletes the entry. A stored
    ///   payload stops decoding when the item's `Codable` shape changes, which an app update
    ///   routinely does. Such an entry can never be served again, so there is nothing to protect
    ///   by keeping it, and leaving it would strand it on the consumer's disk for good. An entry
    ///   that is empty, which is what a truncated write leaves behind, fails to decode and is
    ///   treated the same way.
    /// - **A failure to read an entry that is present.** Throws. A permissions or I/O fault is a
    ///   real fault, and reporting it as an ordinary cache miss would hide it.
    ///
    /// The bytes are read and decoded here rather than through `loadResource(filename:)`,
    /// because that call reports all three outcomes as one error type that is internal to
    /// `Files`, so the distinction cannot be drawn from outside that package. Reading directly
    /// also means the error a caller sees for a genuine fault is the file system's own, which a
    /// caller can match on, rather than one it has no way to name.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: The stored resource, or `nil` if there is none to serve.
    /// - Throws: An error if an entry is present but could not be read, or if an entry that does
    ///   not decode could not be deleted.
    func resource(for identifier: Item.ID) throws -> StoredResource? {

        let store = try store
        let name = filename(for: identifier)
        let entry = store.folder.resource(filename: name)

        guard entry.exists(using: store.agent) else {
            return nil
        }

        let data = try entry.read(using: store.agent)

        guard let resource = try? FileSystemLayout
            .makeEntryDecoder()
            .decode(StoredResource.self, from: data) else {
            try store.deleteResource(filename: name)
            return nil
        }

        return resource
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
