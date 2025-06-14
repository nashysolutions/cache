//
//  FileSystemDatabase.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation
import Files

struct FileSystemDatabase<Item: Identifiable & Codable>: Database {

    let storage: FileSystemStorage<Item>
    let recordCountMaximum: UInt
    
    nonisolated init(
        fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil,
        recordCountMaximum: UInt
    ) {
        self.storage = FileSystemStorage<Item>(
            fileSystemDirectory: fileSystemDirectory,
            subfolder: subfolder
        )
        self.recordCountMaximum = recordCountMaximum
    }
}
