# QuickStart

This article explains how to get started quickly.

## Overview

Your model must conform to `Identifiable`. You have the option of a ``VolatileCache`` or a ``FileSystemCache``.  If you choose, ``FileSystemCache``, then your model must also conform to `Codable`.

```swift
import Cache

struct Cheese: Identifiable, Codable {
    let id: Int
    let name: String
}
```

### VolatileCache

### Step 1

Instantiate your cache.

```swift
final class ContentViewModel: ObservableObject {
    
    private let cache = VolatileCache<Cheese>()
    
    func save(cheese: Cheese) async throws(ContentViewModelError) {
        do {
            try await cache.stash(cheese, duration: .long)
        } catch {
            throw ContentViewModelError.cachingFailed
        }
    }
}
```

### Step 2

There is no step 2!

### FileSystemCache

### Step 1

Instantiate your cache.

```swift
final class ContentViewModel: ObservableObject {
    
    private let cache = FileSystemCache<Cheese>(.caches, subfolder: "Cheeses")
    
    func save(cheese: Cheese) async throws(ContentViewModelError) {
        do {
            try await cache.stash(cheese, duration: .long)
        } catch {
            throw ContentViewModelError.cachingFailed
        }
    }
}
```

### Step 2

There is no step 2!...unless, you haven't already been using the awesome [Files](https://github.com/nashysolutions/files) library and setup a `FileSystemContext` for your environment. If not, no problem, just copy and paste the following boilerplate.

```swift
import Foundation
import Files

/// A wrapper for the `FileManager` from Foundation. This will interface with our environment.
struct FileSystemLiveAgent: FileSystemContext {
        
    let fileManager: FileManager
    
    func fileExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }
    
    func folderExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    func moveResource(from fromURL: URL, to toURL: URL) throws {
        try fileManager.moveItem(at: fromURL, to: toURL)
    }
    
    func copyResource(from fromURL: URL, to toURL: URL) throws {
        try fileManager.copyItem(at: fromURL, to: toURL)
    }
    
    func deleteLocation(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    func removeDirectory(at url: URL) throws {
        // Only remove if it is a directory
        if folderExists(at: url) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        try data.write(to: url, options: options)
    }
    
    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
    
    func url(for directory: Files.FileSystemDirectory) throws -> URL {
        switch directory {
        case .documents:
            return try fileManager.url(for: .documentDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
        case .caches:
            return try fileManager.url(for: .cachesDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
        case .temporary:
            return fileManager.temporaryDirectory
        case .applicationSupport:
            return try fileManager.url(for: .applicationSupportDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
        }
    }
}

extension FileSystemClientKey: @retroactive DependencyKey {

    public static var liveValue = FileSystemClient(
        fileExists: { url in
            let agent = FileSystemLiveAgent(fileManager: .default)
            return agent.fileExists(at: url)
        },
        folderExists: { url in
            let agent = FileSystemLiveAgent(fileManager: .default)
            return agent.folderExists(at: url)
        },
        createDirectory: { url in
            let agent = FileSystemLiveAgent(fileManager: .default)
            try agent.createDirectoryIfNecessary(at: url)
        },
        deleteLocation: { url in
            let agent = FileSystemLiveAgent(fileManager: .default)
            try agent.deleteLocation(at: url)
        },
        moveResource: { fromURL, toURL in
            let agent = FileSystemLiveAgent(fileManager: .default)
            try agent.moveResource(from: fromURL, to: toURL)
        },
        copyResource: { fromURL, toURL in
            let agent = FileSystemLiveAgent(fileManager: .default)
            try agent.copyResource(from: fromURL, to: toURL)
        },
        write: { data, url, options in
            let agent = FileSystemLiveAgent(fileManager: .default)
            try agent.write(data, to: url, options: options)
        },
        read: { url in
            let agent = FileSystemLiveAgent(fileManager: .default)
            return try agent.read(from: url)
        },
        urlForDirectory: { directory in
            let agent = FileSystemLiveAgent(fileManager: .default)
            return try agent.url(for: directory)
        }
    )
}

extension FileSystemResourceClientKey: @retroactive DependencyKey {
    
    public static var liveValue: FileSystemResourceClient {
        return FileSystemResourceClient(makeStore: { directory, subfolder in
            let agent = FileSystemLiveAgent(fileManager: .default)
            return try FileSystemFolderStore(agent: agent, kind: directory, subfolder: subfolder)
        })
    }
}
```

To learn more about `liveValue` see the readme for [Pointfree's](https://www.pointfree.co) library named [Dependencies](https://github.com/pointfreeco/swift-dependencies).
