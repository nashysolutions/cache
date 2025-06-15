//
//  VolatileDatabase.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A non-persistent, in-memory implementation of `Database` backed by `VolatileStorage`.
///
/// `VolatileDatabase` manages resource caching entirely in memory and is suitable for ephemeral
/// use cases such as testing, short-lived caches, or in-memory stores where persistence is not required.
struct VolatileDatabase<Item: Identifiable>: Database {

    /// The underlying in-memory storage provider.
    let storage = VolatileStorage<Item>()
    
    nonisolated init() {
        
    }
}
