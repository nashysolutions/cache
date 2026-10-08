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
struct CodableEntry<Item: Identifiable & Codable & Sendable>: Sendable, ExpiringResource, Codable {

    /// The wrapped codable item associated with this entry.
    let item: Item

    /// The date at which this entry is considered expired.
    let expiry: Date
}
