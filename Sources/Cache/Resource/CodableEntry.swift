//
//  CodableEntry.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A codable variant of ``Entry`` that wraps an identifiable and codable item.
///
/// `CodableEntry` is designed for use in persistent or serialisable storage contexts, such as
/// file system or database-backed caches.
///
/// It is unrelated to the public, deprecated ``CodableResource``, which is kept only so that code
/// written against 6.0.0 still compiles, and which nothing in the package stores.
struct CodableEntry<Item: Identifiable & Codable & Sendable>: Sendable, ExpiringResource, Codable {

    /// The wrapped codable item associated with this entry.
    let item: Item

    /// The date at which this entry is considered expired.
    let expiry: Date
}
