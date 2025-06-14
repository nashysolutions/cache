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
///
/// It automatically purges all stored resources when the configured maximum count is reached.
struct VolatileDatabase<Item: Identifiable>: Database {

    /// The underlying in-memory storage provider.
    let storage = VolatileStorage<Item>()

    /// The maximum number of resources allowed before triggering a reset.
    ///
    /// When the number of stored resources meets or exceeds this value,
    /// `clearStorageIfNecessary()` will purge the entire storage.
    let recordCountMaximum: UInt
}
