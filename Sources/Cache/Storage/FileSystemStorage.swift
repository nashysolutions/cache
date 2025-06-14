//
//  FileSystemStorage.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

@ResourceStorageActor
final class FileSystemStorage<Item: Identifiable>: Storage {
    
    var count: Int { fatalError() }
    
    func insert(_ resource: Resource<Item>) {
        fatalError()
    }
    
    func remove(_ resource: Resource<Item>) {
        fatalError()
    }
    
    func removeAll() {
        fatalError()
    }
    
    func first(where: (Resource<Item>) -> Bool) -> Resource<Item>? {
        fatalError()
    }
}
