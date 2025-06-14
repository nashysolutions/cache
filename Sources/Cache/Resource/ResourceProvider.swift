//
//  ResourceProvider.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

@ResourceStorageActor
protocol ResourceProvider {
    
    associatedtype Item: Identifiable
    
    var recordCountMaximum: UInt { get }
    
    func stash(_ resource: Resource<Item>) throws
    func resource(for identifier: Item.ID) throws -> Resource<Item>?
    func removeResource(for identifier: Item.ID) throws
    func removeAll() throws
}
