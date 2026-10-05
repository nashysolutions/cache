//
//  Resource.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A lightweight wrapper that associates an identifiable item with an expiry date,
/// without requiring the item to conform to `Codable`.
///
/// `Resource` is used to track in-memory items with a defined expiration deadline.
struct Resource<Item: Identifiable & Sendable>: Sendable, ExpiringResource {

    /// The wrapped item associated with this resource.
    let item: Item

    /// The date at which this resource is considered expired.
    let expiry: Date
}
