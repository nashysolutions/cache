//
//  Resource.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A wrapper that associates an identifiable item with an expiry date.
///
/// `Resource` is used to track cacheable or temporary data,
/// enabling expiry-based invalidation and lookup by identifier.
struct Resource<Item: Identifiable>: Hashable {
    
    /// The underlying identifiable item.
    let item: Item

    /// The date at which this resource expires.
    let expiry: Date

    /// The unique identifier for the wrapped item.
    ///
    /// This is derived from the item's `id`.
    var identifier: Item.ID {
        item.id
    }

    /// A Boolean value indicating whether the resource is expired.
    ///
    /// The resource is considered expired if its expiry date is earlier than the current date.
    var isExpired: Bool {
        expiry < Date()
    }

    /// Determines equality based on the identifier of the wrapped item.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side resource.
    ///   - rhs: The right-hand side resource.
    /// - Returns: `true` if the identifiers are equal; otherwise, `false`.
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }

    /// Hashes the identifier of the wrapped item into the provided hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the identifier.
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
