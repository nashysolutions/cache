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
public struct Resource<Item: Identifiable>: ExpiringResource, Hashable {

    /// The wrapped item associated with this resource.
    public let item: Item

    /// The date at which this resource is considered expired.
    public let expiry: Date

    /// Creates a new resource from the given item and expiry.
    ///
    /// - Parameters:
    ///   - item: The identifiable item to wrap.
    ///   - expiry: The date at which the resource should expire.
    public init(item: Item, expiry: Date) {
        self.item = item
        self.expiry = expiry
    }

    /// Compares two resources for equality using their identifiers.
    ///
    /// - Parameters:
    ///   - lhs: The first resource.
    ///   - rhs: The second resource.
    /// - Returns: `true` if both resources wrap items with the same identifier.
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }

    /// Hashes the resource using its identifier.
    ///
    /// - Parameter hasher: The hasher to use when combining the identifier.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
