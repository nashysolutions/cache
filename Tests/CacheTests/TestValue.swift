//
//  TestValue.swift
//  
//
//  Created by Robert Nash on 08/02/2023.
//

import Foundation

struct TestValue: Identifiable {
    
    var id: Int {
        count
    }
    
    let count: Int
}

struct CodableTestValue: Identifiable, Codable {
    
    var id: Int {
        count
    }
    
    let count: Int
}
