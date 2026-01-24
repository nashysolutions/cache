//
//  TestValue.swift
//  
//
//  Created by Robert Nash on 08/02/2023.
//

import Foundation

struct TestValue: Identifiable, LosslessStringConvertible, Sendable {
    
    let count: String

    var id: String { count }

    var description: String { count }

    init(count: String) {
        self.count = count
    }

    init?(_ description: String) {
        guard !description.isEmpty else { return nil }
        self.count = description
    }
}

struct CodableTestValue: Identifiable, Codable {
    
    var id: String {
        count
    }
    
    let count: String
}
