//
//  Deprecated.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Foundation

// Shims that keep code written against 6.0.0 compiling, each with a deprecation warning that names
// what to do instead. Everything in this file is removed in 8.0.0.

/// An item paired with the date at which it expires.
///
/// Nothing in this package accepts or returns a `Resource`. ``VolatileCache`` and
/// ``FileSystemCache`` take an item and an ``Expiry``, and serve the item back. The type is kept,
/// deprecated, only so that code written against 6.0.0, which made it public, still compiles. The
/// caches no longer store it, so a value of it is not connected to anything in a cache.
///
/// Equality and hashing use the wrapped item's identifier alone, not the item or the expiry, as
/// they did in 6.0.0. Two resources wrapping different items with the same identifier are equal.
@available(*, deprecated, message: "Nothing in Cache accepts or returns Resource. Pass the item to stash(_:duration:) directly, or declare your own type to pair an item with an expiry date. Resource is removed in 8.0.0.")
public struct Resource<Item: Identifiable & Sendable>: Sendable, Hashable {

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
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item.id == rhs.item.id
    }

    /// Hashes the resource using its identifier.
    ///
    /// - Parameter hasher: The hasher to use when combining the identifier.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(item.id)
    }
}

/// A codable variant of ``Resource``: an identifiable, codable item paired with the date at which
/// it expires.
///
/// Nothing in this package accepts or returns a `CodableResource`. ``FileSystemCache`` takes an
/// item and an ``Expiry``, and serves the item back. The type is kept, deprecated, only so that
/// code written against 6.0.0, which made it public, still compiles. The cache no longer stores
/// it, so a value of it is not connected to anything on disk, although it encodes to the same JSON
/// keys, `item` and `expiry`, as it did in 6.0.0.
///
/// Equality and hashing use the wrapped item's identifier alone, not the item or the expiry, as
/// they did in 6.0.0. Two resources wrapping different items with the same identifier are equal.
@available(*, deprecated, message: "Nothing in Cache accepts or returns CodableResource. Pass the item to stash(_:duration:) directly, or declare your own type to pair an item with an expiry date. CodableResource is removed in 8.0.0.")
public struct CodableResource<Item: Identifiable & Codable & Sendable>: Sendable, Codable, Hashable {

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
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item.id == rhs.item.id
    }

    /// Hashes the resource using its identifier.
    ///
    /// - Parameter hasher: The hasher to use when combining the identifier.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(item.id)
    }
}

extension Cache {

    /// Removes nothing, and throws `CocoaError.featureUnsupported`.
    ///
    /// `removeExpired()` became a requirement of ``Cache`` after 6.0.0. This default exists
    /// only so that a conformance written against 6.0.0, which has no sweep of its own, still
    /// compiles. Nothing here can enumerate that conformance's entries, so no sweep can run, and the
    /// default says so by throwing. Returning `0` would report a sweep that found nothing expired,
    /// which a caller could not tell apart from a sweep that never ran.
    ///
    /// The error is Foundation's own code for an unsupported feature. The package declares no error
    /// type of its own and passes on the errors Foundation and the file system raise, so a caller
    /// matches this one the same way, with `catch CocoaError.featureUnsupported`.
    ///
    /// ``VolatileCache`` and ``FileSystemCache`` implement the sweep, so neither uses this default.
    /// It is deprecated, so a conformance that relies on it gets a warning at compile time, and it
    /// is removed in 8.0.0, after which every conformance must implement `removeExpired()` itself.
    ///
    /// - Returns: Nothing; the default always throws.
    /// - Throws: `CocoaError` with the code `featureUnsupported`, on every call.
    @available(*, deprecated, message: "Implement removeExpired() in this conformance. The default removes nothing and always throws CocoaError.featureUnsupported, and it is removed in 8.0.0.")
    @discardableResult
    public func removeExpired() async throws -> Int {
        throw CocoaError(
            .featureUnsupported,
            userInfo: [
                NSDebugDescriptionErrorKey: "\(Self.self) does not implement removeExpired(), so no expired entries were removed."
            ]
        )
    }
}
