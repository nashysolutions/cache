//
//  DummyAgent.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

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
    }
    
    private(set) var called: [Endpoint] = []
    
    var fileExistsHandler: ((URL) -> Bool)?
    var folderExistsHandler: ((URL) -> Bool)?
    var createDirectoryHandler: ((URL) throws -> Void)?
    var removeDirectoryHandler: ((URL) throws -> Void)?
    var deleteLocationHandler: ((URL) throws -> Void)?
    var moveResourceHandler: ((URL, URL) throws -> Void)?
    var copyResourceHandler: ((URL, URL) throws -> Void)?
    var writeHandler: ((Data, URL, NSData.WritingOptions) throws -> Void)?
    var readHandler: ((URL) throws -> Data)?
    var urlForDirectoryHandler: ((FileSystemDirectory) throws -> URL)?
    
    func fileExists(at url: URL) -> Bool {
        called.append(.fileExists)
        return fileExistsHandler?(url) ?? false
    }
    
    func folderExists(at url: URL) -> Bool {
        called.append(.folderExists)
        return folderExistsHandler?(url) ?? false
    }
    
    func createDirectory(at url: URL) throws {
        called.append(.createDirectory)
        try createDirectoryHandler?(url)
    }
    
    func removeDirectory(at url: URL) throws {
        called.append(.removeDirectory)
        try removeDirectoryHandler?(url)
    }
    
    func deleteLocation(at url: URL) throws {
        called.append(.deleteLocation)
        try deleteLocationHandler?(url)
    }
    
    func moveResource(from fromURL: URL, to toURL: URL) throws {
        called.append(.moveResource)
        try moveResourceHandler?(fromURL, toURL)
    }
    
    func copyResource(from fromURL: URL, to toURL: URL) throws {
        called.append(.copyResource)
        try copyResourceHandler?(fromURL, toURL)
    }
    
    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        called.append(.write)
        try writeHandler?(data, url, options)
    }
    
    func read(from url: URL) throws -> Data {
        called.append(.read)
        return try readHandler?(url) ?? Data()
    }
    
    func url(for directory: FileSystemDirectory) throws -> URL {
        called.append(.urlForDirectory)
        return try urlForDirectoryHandler?(directory) ?? URL(fileURLWithPath: "/dev/null")
    }
}
