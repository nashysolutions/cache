//
//  DummyAgent.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

/// A `FileSystemContext` that records which of its methods were called and touches nothing.
///
/// Every query answers as an empty file system would: nothing exists, a read returns no bytes,
/// and a directory lists nothing.
final class DummyAgent: FileSystemContext {

    enum Endpoint {
        case fileExists
        case folderExists
        case createDirectory
        case removeDirectory
        case deleteLocation
        case moveResource
        case copyResource
        case write
        case read
        case urlForDirectory
        case contentsOfDirectory
    }

    private(set) var called: [Endpoint] = []

    func fileExists(at url: URL) -> Bool {
        called.append(.fileExists)
        return false
    }

    func folderExists(at url: URL) -> Bool {
        called.append(.folderExists)
        return false
    }

    func createDirectory(at url: URL) throws {
        called.append(.createDirectory)
    }

    func removeDirectory(at url: URL) throws {
        called.append(.removeDirectory)
    }

    func deleteLocation(at url: URL) throws {
        called.append(.deleteLocation)
    }

    func moveResource(from fromURL: URL, to toURL: URL) throws {
        called.append(.moveResource)
    }

    func copyResource(from fromURL: URL, to toURL: URL) throws {
        called.append(.copyResource)
    }

    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        called.append(.write)
    }

    func read(from url: URL) throws -> Data {
        called.append(.read)
        return Data()
    }

    func url(for directory: FileSystemDirectory) throws -> URL {
        called.append(.urlForDirectory)
        return URL(fileURLWithPath: "/dev/null")
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey], options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        called.append(.contentsOfDirectory)
        return []
    }
}
