//
//  FileSystemDatabase.swift
//  cache
//
//  Created by Robert Nash on 13/06/2025.
//

import Foundation
import Files

/// A file system-backed database implementation that stores identifiable, codable resources.
///
/// `FileSystemDatabase` conforms to ``Database`` and provides persistent storage using a ``FileSystemStorage`` backend.
/// It is designed for use cases where resource data must survive app restarts or be shared between components.
///
/// - Note: The wrapped item type must conform to both `Identifiable` and `Codable`.
actor FileSystemDatabase<Item: Identifiable & Codable & Sendable>: Database {

    /// The file system storage used to persist resources.
    let storage: FileSystemStorage<Item>
    
    /// Creates a new file system-backed database.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The base directory where resources are stored.
    ///   - subfolder: An optional subfolder path under the base directory. Defaults to `nil`.
    init(
        fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil
    ) {
        self.storage = FileSystemStorage<Item>(
            fileSystemDirectory: fileSystemDirectory,
            subfolder: subfolder
        )
    }
}
