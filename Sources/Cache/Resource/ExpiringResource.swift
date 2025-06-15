//
//  ExpiringResource.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A protocol describing a resource associated with an identifiable item and an expiry date.
protocol IdentifiableResource {
    
    associatedtype Item: Identifiable

    /// The underlying item.
    var item: Item { get }

    /// The identifier derived from the item.
    var identifier: Item.ID { get }
}

extension IdentifiableResource {
    
    /// Returns the identifier of the wrapped item.
    var identifier: Item.ID {
        item.id
    }
}

protocol ExpiringResource: IdentifiableResource {
    /// The expiry date for this resource.
    var expiry: Date { get }
    /// Indicates whether the resource has expired.
    var isExpired: Bool { get }
}

extension ExpiringResource {
    
    /// Whether the resource has expired.
    var isExpired: Bool {
        expiry < Date()
    }
}
