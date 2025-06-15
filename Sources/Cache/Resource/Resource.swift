//
//  Resource.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A wrapper that associates an identifiable item with an expiry date,
/// without requiring Codable conformance.
public struct Resource<Item: Identifiable>: IdentifiableResource /*ExpiringResource*/, Hashable {

    public let item: Item
    public let expiry: Date

    public init(item: Item, expiry: Date) {
        self.item = item
        self.expiry = expiry
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
