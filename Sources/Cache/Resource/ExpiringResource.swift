//
//  ExpiringResource.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A protocol describing a resource associated with an identifiable item and an expiry date.
public protocol ExpiringResource {
    
    associatedtype Item: Identifiable

    /// The underlying item.
    var item: Item { get }

    /// The expiry date for this resource.
    var expiry: Date { get }

    /// The identifier derived from the item.
    var identifier: Item.ID { get }

    /// Indicates whether the resource has expired.
    var isExpired: Bool { get }
}

public extension ExpiringResource {
    
    /// Returns the identifier of the wrapped item.
    var identifier: Item.ID {
        item.id
    }
    
    /// Whether the resource has expired.
    var isExpired: Bool {
        expiry < Date()
    }
}
