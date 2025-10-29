//
//  CodableResource.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A codable variant of ``Resource`` that wraps an identifiable and codable item.
///
/// `CodableResource` is designed for use in persistent or serialisable storage contexts, such as
/// file system or database-backed caches.
///
/// Equality and hashing are based on the wrapped item's identifier, not the full item or expiry date.
public struct CodableResource<Item: Identifiable & Codable & Sendable>: Sendable, ExpiringResource, Codable, Hashable {
    
    /// The wrapped codable item associated with this resource.
    public let item: Item

    /// The date at which this resource is considered expired.
    public let expiry: Date

    /// Creates a new codable resource with the given item and expiry date.
    ///
    /// - Parameters:
    ///   - item: The identifiable, codable item to wrap.
    ///   - expiry: The date at which the resource should expire.
    public init(item: Item, expiry: Date) {
        self.item = item
        self.expiry = expiry
    }

    /// Compares two codable resources for equality using their identifiers.
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
