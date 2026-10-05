//
//  MockFileSystemFolderStore.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

/// A `FileSystemOperations` store that records which of its methods were called and keeps
/// nothing.
///
/// A load always throws, because the store holds nothing to load. Any test that reaches a load
/// therefore fails outright, rather than being handed a value the cache never wrote.
final class MockFileSystemFolderStore<Folder: Directory>: FileSystemOperations {

    enum Endpoint {
        case saveResource
        case loadResource
        case deleteResource
        case updateResource
        case saveData
        case loadData
    }

    let folder: Folder
    let agent: DummyAgent

    private(set) var called: [Endpoint] = []

    init(agent: DummyAgent = DummyAgent(), folder: Folder = DummyFolder()) {
        self.agent = agent
        self.folder = folder
    }

    func saveResource<Resource: Encodable>(_ resource: Resource, filename name: String) throws {
        called.append(.saveResource)
    }

    func loadResource<Resource: Decodable>(filename: String) throws -> Resource {
        called.append(.loadResource)
        throw NSError(domain: "mock", code: 1)
    }

    func deleteResource(filename: String) throws {
        called.append(.deleteResource)
    }

    func updateResource<Resource: Codable>(filename name: String, modify: (inout Resource) -> Void) throws {
        called.append(.updateResource)
    }

    func saveData(_ data: Data, withName name: String) throws {
        called.append(.saveData)
    }

    func loadData(named name: String) throws -> Data {
        called.append(.loadData)
        return Data()
    }
}
