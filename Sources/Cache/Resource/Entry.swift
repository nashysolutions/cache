//
//  Entry.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A lightweight wrapper that associates an identifiable item with an expiry date,
/// without requiring the item to conform to `Codable`.
///
/// `Entry` is used to track in-memory items with a defined expiration deadline.
///
/// It is unrelated to the public, deprecated ``Resource``, which is kept only so that code written
/// against 6.0.0 still compiles, and which nothing in the package stores.
struct Entry<Item: Identifiable & Sendable>: Sendable, ExpiringResource {

    /// The wrapped item associated with this entry.
    let item: Item

    /// The date at which this entry is considered expired.
    let expiry: Date
}
