//
//  FileSystemDatabase.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation

struct FileSystemDatabase<Item: Identifiable>: Database {
    let storage: FileSystemStorage<Item>
    let recordCountMaximum: UInt
}
