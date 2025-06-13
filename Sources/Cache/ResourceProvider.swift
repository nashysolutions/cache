//
//  ResourceProvider.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

protocol ResourceProvider {
    
    associatedtype Item: Identifiable
    associatedtype ResourceItem = Resource<Item>
    
    func stash(_ resource: ResourceItem)
    func resource(for identifier: Item.ID) -> ResourceItem?
    func removeResource(for identifier: Item.ID)
    func removeAll()
    init(recordCountMaximum: Int)
}
