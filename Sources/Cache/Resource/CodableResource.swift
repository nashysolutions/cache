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
struct CodableResource<Item: Identifiable & Codable & Sendable>: Sendable, ExpiringResource, Codable {

    /// The wrapped codable item associated with this resource.
    let item: Item

    /// The date at which this resource is considered expired.
    let expiry: Date
}
