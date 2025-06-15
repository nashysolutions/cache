//
//  MockFileSystemFolderStore.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

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

    var saveHandler: ((AnyResourceBox, String) throws -> Void)?
    var loadHandler: ((String) throws -> AnyResourceBox)?
    var deleteHandler: ((String) throws -> Void)?
    var updateHandler: ((String, (inout Any) -> Void) throws -> Void)?
    var saveDataHandler: ((Data, String) throws -> Void)?
    var loadDataHandler: ((String) throws -> Data)?
    
    init(agent: DummyAgent = DummyAgent(), folder: Folder = DummyFolder()) {
        self.agent = agent
        self.folder = folder
    }

    func saveResource<Resource: Encodable>(_ resource: Resource, filename name: String) throws {
        called.append(.saveResource)
        try saveHandler?(AnyResourceBox(resource), name)
    }

    func loadResource<Resource: Decodable>(filename: String) throws -> Resource {
        called.append(.loadResource)
        let box = try loadHandler?(filename) ?? {
            throw NSError(domain: "mock", code: 1)
        }()
        return try box.cast(to: Resource.self)
    }

    func deleteResource(filename: String) throws {
        called.append(.deleteResource)
        try deleteHandler?(filename)
    }

    func updateResource<Resource: Codable>(filename name: String, modify: (inout Resource) -> Void) throws {
        called.append(.updateResource)
        // Stub
    }

    func saveData(_ data: Data, withName name: String) throws {
        called.append(.saveData)
        try saveDataHandler?(data, name)
    }

    func loadData(named name: String) throws -> Data {
        called.append(.loadData)
        return try loadDataHandler?(name) ?? Data()
    }
}
