//
//  FileSystemStorage.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import FoundationDependencies
import Dependencies

@ResourceStorageActor
final class FileSystemStorage<Item: Identifiable>: Storage {
    
    @Dependency(\.fileSystemClient) var fileSystemClient
    
    var count: Int { fatalError() }
    
    func insert(_ resource: Resource<Item>) throws {
        fatalError()
    }
    
    func remove(_ resource: Resource<Item>) throws {
        fatalError()
    }
    
    func removeAll() throws {
        fatalError()
    }
    
    func first(where: (Resource<Item>) -> Bool) throws -> Resource<Item>? {
        fatalError()
    }
}
