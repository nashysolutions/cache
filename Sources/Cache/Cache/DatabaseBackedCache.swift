//
//  DatabaseBackedCache.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A cache that delegates its storage and retrieval operations to an underlying `Database` instance.
///
/// `DatabaseBackedCache` builds upon the `Cache` protocol by requiring a concrete database type
/// to act as the backing store for cached items. This allows for reusable caching behaviours across
/// various database implementations (e.g. in-memory, file-based, persistent).
protocol DatabaseBackedCache: Cache {

    /// The underlying database used to manage cached resources.
    ///
    /// The database is responsible for storing and retrieving `Resource`-wrapped items, and for
    /// removing an expired one when it is looked up. It evicts nothing else.
    associatedtype D: Database where D.Item == Item

    /// The backing database that powers this cache.
    var database: D { get }
}
