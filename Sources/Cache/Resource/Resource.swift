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
///
/// This type supports hashing and equality based on the wrapped item’s identifier, not the full item or expiry.
struct Resource<Item: Identifiable & Sendable>: Sendable, ExpiringResource, Hashable {

    /// The wrapped item associated with this resource.
    let item: Item

    /// The date at which this resource is considered expired.
    let expiry: Date

    /// Compares two resources for equality using their identifiers.
    ///
    /// - Parameters:
    ///   - lhs: The first resource.
    ///   - rhs: The second resource.
    /// - Returns: `true` if both resources wrap items with the same identifier.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }

    /// Hashes the resource using its identifier.
    ///
    /// - Parameter hasher: The hasher to use when combining the identifier.
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
