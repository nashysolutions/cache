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
/// Entries are written into a folder scoped to both the layout version and the item type, and
/// carry a recognisable extension, so this storage can identify its own files and cannot reach
/// another item type's. See ``FileSystemLayout`` for the shape and for why it is scoped that way.
///
/// Every operation reads and writes through the file system context directly rather than through
/// `Files`' resource operations. Those wrap each failure in an error type that is internal to
/// `Files`, which a consumer cannot name and therefore cannot match on. Going through the context
/// means the error a caller sees is the file system's own.
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
    /// The store is scoped to the type folder described by ``FileSystemLayout``, so nothing this
    /// storage saves, loads or deletes ever sits directly in the consumer's own directory, or in
    /// a folder shared with a cache over a different item type.
    ///
    /// It is rebuilt on every operation rather than held, so a directory that disappears between
    /// operations is recreated on the next one. iOS purges the caches directory under disk
    /// pressure, and a store held from construction would fail every write afterwards.
    ///
    /// - Throws: An error if the store could not be created.
    private var store: any FileSystemOperations {
        get throws {
            // Each level of the path is created as a separate step. An agent whose
            // `createDirectory` does not create intermediate directories would otherwise fail to
            // create the folders below it.
            _ = try fileSystemResourceClient.makeStore(
                fileSystemDirectory,
                subfolder
            )

            _ = try fileSystemResourceClient.makeStore(
                fileSystemDirectory,
                FileSystemLayout.versionedSubfolder(below: subfolder)
            )

            return try fileSystemResourceClient.makeStore(
                fileSystemDirectory,
                FileSystemLayout.typeScopedSubfolder(below: subfolder, for: Item.self)
            )
        }
    }

    /// Inserts a resource into the file system.
    ///
    /// - Parameter resource: The resource to insert.
    /// - Throws: An error if the resource could not be encoded or written to disk.
    func insert(_ resource: Resource) throws {

        let store = try store
        let data = try FileSystemLayout.makeEntryEncoder().encode(resource)

        try store.folder
            .resource(filename: filename(for: resource))
            .write(data: data, using: store.agent)
    }

    /// Removes the entry held for the given identifier, if there is one.
    ///
    /// The entry is deleted by the filename its identifier derives, so it is never read first.
    /// An entry whose payload no longer decodes is therefore removed exactly like any other,
    /// rather than being stuck on disk because reading it is what fails.
    ///
    /// The delete is attempted rather than guarded by an existence check. A check cannot tell an
    /// absent entry from one it is not permitted to look for, so guarding on it reported a
    /// permissions fault as an ordinary "nothing to remove". Attempting the delete and reading
    /// the failure keeps the two apart: see ``reportsNothingThere(_:)``.
    ///
    /// - Parameter identifier: The identifier of the item whose entry should be removed.
    /// - Throws: An error if an entry could not be deleted for any reason other than not being
    ///   there. An identifier with no entry on disk is not an error.
    func remove(for identifier: Item.ID) throws {

        let store = try store
        let entry = store.folder.resource(filename: filename(for: identifier))

        do {
            try store.agent.deleteLocation(at: entry.location)
        } catch let error where reportsNothingThere(error) {
            return
        }
    }

    /// Removes every entry this storage wrote.
    ///
    /// Only files matching the current layout, inside this item type's own folder, are deleted.
    /// The enclosing folders, and anything else inside them, are left alone, including files a
    /// consumer or another component put there and entries belonging to a cache over a different
    /// item type.
    ///
    /// - Throws: An error if the folder could not be enumerated, or an entry could not be deleted.
    func removeAll() throws {
        try store.deleteFiles(matching: Self.isEntry)
    }

    /// Removes every entry this storage wrote whose expiry precedes the given instant.
    ///
    /// The sweep lists this item type's own folder and judges each entry by the `expiry` it
    /// carries, decoding that field alone through ``FileSystemLayout/EntryExpiry``, which is
    /// where the reason for not decoding the item lives.
    ///
    /// Files this sweep leaves alone:
    ///
    /// - An entry that has not expired, whether or not its item still decodes.
    /// - An entry whose `expiry` cannot be read: an empty file left by a truncated write, or bytes
    ///   that are not an entry at all. Nothing says such an entry has expired, so this sweep does
    ///   not remove it and does not count it. The next lookup of its identifier clears it, as
    ///   ``resource(for:)`` describes.
    /// - Anything that is not an entry of the current layout, by the same test ``removeAll()``
    ///   applies.
    ///
    /// An entry that disappears between being listed and being read or deleted, which another
    /// cache over the same folder can cause, is treated as already gone and not counted. Any
    /// other failure to read or delete is a fault and surfaces, on the rule given at
    /// ``reportsNothingThere(_:)``. Entries removed before the fault stay removed; the sweep is
    /// not transactional.
    ///
    /// - Parameter now: The instant to judge expiry against.
    /// - Returns: The number of entries removed.
    /// - Throws: An error if the folder could not be created or listed, an entry could not be
    ///   read, or an expired entry could not be deleted.
    func removeExpired(asOf now: Date) throws -> Int {

        let store = try store
        let decoder = FileSystemLayout.makeEntryDecoder()
        var removed = 0

        let entries = try store.contents(includingPropertiesForKeys: [.isRegularFileKey], options: [])

        for entry in entries where Self.isEntry(entry) {

            let data: Data

            do {
                data = try store.agent.read(from: entry.url)
            } catch let error where reportsNothingThere(error) {
                continue
            }

            // The comparison is the one `ExpiringResource.isExpired(asOf:)` makes. It cannot be
            // called here because an expiry on its own is not a resource: there is no item to
            // wrap, and requiring one would reintroduce the dependence on decoding it.
            guard let expiry = try? decoder.decode(FileSystemLayout.EntryExpiry.self, from: data).expiry,
                  expiry < now else {
                continue
            }

            do {
                try store.agent.deleteLocation(at: entry.url)
            } catch let error where reportsNothingThere(error) {
                continue
            }

            removed += 1
        }

        return removed
    }

    /// Whether a listed file is an entry this storage wrote in the current layout.
    ///
    /// Shared by ``removeAll()`` and ``removeExpired(asOf:)``, so the two sweeps cannot disagree
    /// about what counts as an entry.
    private static func isEntry(_ entry: DirectoryEntry) -> Bool {
        entry.value(\.isRegularFile) == true
        && FileSystemLayout.isEntryFilename(entry.url.lastPathComponent)
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
    ///
    ///   This is the step that needs the type scoping in ``FileSystemLayout``. "Does not decode"
    ///   is also exactly what a different item type's entry looks like, so before entries were
    ///   scoped by type, two caches sharing a directory deleted each other's data here.
    /// - **A failure to read an entry that is present.** Throws. A permissions or I/O fault is a
    ///   real fault, and reporting it as an ordinary cache miss would hide it.
    ///
    /// The read is attempted rather than guarded by an existence check, for the reason given on
    /// ``reportsNothingThere(_:)``: a directory that exists but cannot be searched answers an
    /// existence check with "no", which turned a permissions fault into a miss.
    ///
    /// The bytes are decoded here rather than through `loadResource(filename:)`, because that
    /// call reports all three outcomes as one error type that is internal to `Files`, so the
    /// distinction cannot be drawn from outside that package.
    ///
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: The stored resource, or `nil` if there is none to serve.
    /// - Throws: An error if an entry could not be read for any reason other than not being
    ///   there, or if an entry that does not decode could not be deleted.
    func resource(for identifier: Item.ID) throws -> StoredResource? {

        let store = try store
        let entry = store.folder.resource(filename: filename(for: identifier))

        let data: Data

        do {
            data = try entry.read(using: store.agent)
        } catch let error where reportsNothingThere(error) {
            return nil
        }

        guard let resource = try? FileSystemLayout
            .makeEntryDecoder()
            .decode(StoredResource.self, from: data) else {
            try store.agent.deleteLocation(at: entry.location)
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
    /// - Parameter identifier: The identifier of the item.
    /// - Returns: A string representing the filename.
    private func filename(for identifier: Item.ID) -> String {
        FileSystemLayout.entryFilename(for: String(describing: identifier))
    }
}

/// Whether an error reports that the thing operated on was not there.
///
/// This is what separates a miss from a fault, and it is deliberately narrow. Only Foundation's
/// two not-found codes qualify; every other error, including every error a consumer-supplied
/// `FileSystemContext` raises, is a fault and surfaces.
///
/// The narrowness is the whole point, and the codes were measured rather than remembered. When a
/// directory exists but cannot be searched, Foundation reports a **permissions** error for a file
/// that is not there, not a not-found error: `CocoaError` 257 on a read and 513 on a delete,
/// where an ordinary absence gives 260 and 4. A rule that treated "cannot determine" as "not
/// there" would therefore report an unreadable cache directory as an ordinary miss, for every
/// identifier, forever. That is the laundering this function exists to prevent.
///
/// - Parameter error: The error a read or delete failed with.
/// - Returns: `true` only if Foundation said the file was not there.
private func reportsNothingThere(_ error: any Error) -> Bool {

    guard let error = error as? CocoaError else {
        return false
    }

    return error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile
}
