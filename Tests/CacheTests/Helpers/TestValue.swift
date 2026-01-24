//
//  TestValue.swift
//  
//
//  Created by Robert Nash on 08/02/2023.
//

import Foundation

struct TestValue<Item: Codable & Sendable & Hashable>: Identifiable {
    
    var id: Item {
        count
    }
    
    let count: Item
}

struct CodableTestValue<Item: Codable & Sendable & Hashable>: Identifiable, Codable {
    
    var id: Item {
        count
    }
    
    let count: Item
}
