//
//  SandboxAgent.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Foundation
import Files

/// A `FileSystemContext` backed by a real `FileManager`, rooted at a throwaway directory.
///
/// Every ``FileSystemDirectory`` case resolves to the same `root`, so a test can exercise the
/// on-disk behaviour of a cache, what it writes and what it deletes, against a real file system
/// without touching a real app container.
struct SandboxAgent: FileSystemContext, Sendable {

    /// The directory that stands in for every well-known app directory.
    let root: URL

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

    func url(for directory: FileSystemDirectory) throws -> URL {
        root
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
