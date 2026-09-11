//
//  FileManagerContext.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Foundation
import Files

/// A `FileSystemContext` backed by the real file system, through `FileManager`.
///
/// This is what makes ``FileSystemCache`` write to disk without a consumer supplying anything.
/// Before it existed, `fileSystemResourceClient` had no live value, so a consumer who had not
/// written the dependency boilerplate got a cache whose writes went nowhere.
///
/// It is deliberately not public. A consumer who needs a different file system supplies their own
/// context through `fileSystemResourceClient`, and a consumer who does not should never have to
/// name this type.
///
/// Every operation is `FileManager`'s own, so every failure is `FileManager`'s own error, which a
/// caller can match on. Nothing here converts a failure into a success, and nothing here checks
/// for a condition the caller has already checked: a delete for a path that is not there throws,
/// rather than quietly reporting success. That matches the sandbox agent the on-disk tests run
/// against, so the behaviour those tests pin is the behaviour a shipping app gets.
struct FileManagerContext: FileSystemContext, Sendable {

    /// `FileManager.default` is reached through a computed property rather than stored, so this
    /// type carries no non-`Sendable` state and can cross the `@Sendable` boundary that
    /// `FileSystemResourceClient.makeStore` imposes on its factory closure.
    private var manager: FileManager { .default }

    func fileExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = manager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue == false
    }

    func folderExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = manager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func moveResource(from fromURL: URL, to toURL: URL) throws {
        try manager.moveItem(at: fromURL, to: toURL)
    }

    func copyResource(from fromURL: URL, to toURL: URL) throws {
        try manager.copyItem(at: fromURL, to: toURL)
    }

    func deleteLocation(at url: URL) throws {
        try manager.removeItem(at: url)
    }

    func createDirectory(at url: URL) throws {
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func removeDirectory(at url: URL) throws {
        try manager.removeItem(at: url)
    }

    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        try data.write(to: url, options: options)
    }

    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    /// Resolves one of the well-known app directories, creating it if the system has not already.
    ///
    /// `create: true` is what makes `.applicationSupport` usable: unlike `.documents` and
    /// `.caches`, it does not exist in a fresh app container until something makes it, and a
    /// cache that could not be created there would otherwise fail on first use.
    ///
    /// - Parameter directory: The directory to resolve.
    /// - Returns: The location of that directory.
    /// - Throws: `FileManager`'s error if the directory could not be resolved or created.
    func url(for directory: FileSystemDirectory) throws -> URL {

        guard let searchPath = directory.searchPath else {
            return manager.temporaryDirectory
        }

        return try manager.url(
            for: searchPath,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        try manager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        )
    }
}
