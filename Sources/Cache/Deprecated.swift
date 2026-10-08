//
//  Deprecated.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Foundation
import Files

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
@available(*, deprecated, message: "Nothing in Cache accepts or returns Resource. Pass the item to setItem(_:expiry:) directly, or declare your own type to pair an item with an expiry date. Resource is removed in 8.0.0.")
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
@available(*, deprecated, message: "Nothing in Cache accepts or returns CodableResource. Pass the item to setItem(_:expiry:) directly, or declare your own type to pair an item with an expiry date. CodableResource is removed in 8.0.0.")
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

// The four operations 7.0.0 renamed. Every name, old and new, is a requirement of `Cache`, and
// each has a default here that calls its counterpart: an old name calls its new name, and a new
// name calls its old one. So a caller of either name reaches a conformance that implements
// either, which keeps 6.0.0 callers, 6.0.0 conformances and test doubles compiling, with a
// warning that names the change. The old requirements themselves are declared, deprecated, in
// Cache.swift, and go with these defaults in 8.0.0.

extension Cache {

    /// Calls ``setItem(_:expiry:)``.
    ///
    /// `stash(_:duration:)` is the 6.0.0 name of ``setItem(_:expiry:)``. This default is what a
    /// caller of the old name reaches on a conformance that implements the new one, which
    /// includes ``VolatileCache`` and ``FileSystemCache``.
    ///
    /// - Parameters:
    ///   - item: The item to be stored in the cache.
    ///   - duration: When the entry stops being served.
    /// - Throws: Whatever ``setItem(_:expiry:)`` throws.
    @available(*, deprecated, renamed: "setItem(_:expiry:)", message: "Use setItem(_:expiry:). stash(_:duration:) is removed in 8.0.0.")
    public func stash(_ item: Item, duration: Expiry) async throws {
        try await setItem(item, expiry: duration)
    }

    /// Calls ``removeItem(for:)``.
    ///
    /// `removeResource(for:)` is the 6.0.0 name of ``removeItem(for:)``. This default is what a
    /// caller of the old name reaches on a conformance that implements the new one, which
    /// includes ``VolatileCache`` and ``FileSystemCache``.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: Whatever ``removeItem(for:)`` throws.
    @available(*, deprecated, renamed: "removeItem(for:)", message: "Use removeItem(for:). removeResource(for:) is removed in 8.0.0.")
    public func removeResource(for identifier: Item.ID) async throws {
        try await removeItem(for: identifier)
    }

    /// Calls ``item(for:)``.
    ///
    /// `resource(for:)` is the 6.0.0 name of ``item(for:)``. This default is what a caller of the
    /// old name reaches on a conformance that implements the new one, which includes
    /// ``VolatileCache`` and ``FileSystemCache``.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: Whatever ``item(for:)`` returns.
    /// - Throws: Whatever ``item(for:)`` throws.
    @available(*, deprecated, renamed: "item(for:)", message: "Use item(for:). resource(for:) is removed in 8.0.0.")
    public func resource(for identifier: Item.ID) async throws -> Item? {
        try await item(for: identifier)
    }

    /// Calls ``removeAll()``.
    ///
    /// `reset()` is the 6.0.0 name of ``removeAll()``. This default is what a caller of the old
    /// name reaches on a conformance that implements the new one, which includes
    /// ``VolatileCache`` and ``FileSystemCache``.
    ///
    /// - Throws: Whatever ``removeAll()`` throws.
    @available(*, deprecated, renamed: "removeAll()", message: "Use removeAll(). reset() is removed in 8.0.0.")
    public func reset() async throws {
        try await removeAll()
    }

    /// Calls `stash(_:duration:)`, for a conformance written against 6.0.0.
    ///
    /// Such a conformance implements `stash(_:duration:)` and not this method. This default lets
    /// it compile, and lets a caller of the new name reach its implementation. It is deprecated,
    /// so the conformance gets a warning at compile time that names the method to implement.
    ///
    /// - Warning: A conformance that implements neither this method nor `stash(_:duration:)`
    ///   also compiles with only that warning, and then each default calls the other, so the
    ///   first call recurses until the stack overflows.
    ///
    /// - Parameters:
    ///   - item: The item to be stored in the cache.
    ///   - expiry: When the entry stops being served.
    /// - Throws: Whatever the conformance's `stash(_:duration:)` throws.
    @available(*, deprecated, message: "Implement setItem(_:expiry:) in this conformance. The default calls stash(_:duration:), and it is removed in 8.0.0.")
    public func setItem(_ item: Item, expiry: Expiry) async throws {
        try await stash(item, duration: expiry)
    }

    /// Calls `removeResource(for:)`, for a conformance written against 6.0.0.
    ///
    /// Such a conformance implements `removeResource(for:)` and not this method. This default lets
    /// it compile, and lets a caller of the new name reach its implementation. It is deprecated,
    /// so the conformance gets a warning at compile time that names the method to implement.
    ///
    /// - Warning: A conformance that implements neither this method nor `removeResource(for:)`
    ///   also compiles with only that warning, and then each default calls the other, so the
    ///   first call recurses until the stack overflows.
    ///
    /// - Parameter identifier: The identifier of the item to remove.
    /// - Throws: Whatever the conformance's `removeResource(for:)` throws.
    @available(*, deprecated, message: "Implement removeItem(for:) in this conformance. The default calls removeResource(for:), and it is removed in 8.0.0.")
    public func removeItem(for identifier: Item.ID) async throws {
        try await removeResource(for: identifier)
    }

    /// Calls `resource(for:)`, for a conformance written against 6.0.0.
    ///
    /// Such a conformance implements `resource(for:)` and not this method. This default lets it
    /// compile, and lets a caller of the new name reach its implementation. It is deprecated, so
    /// the conformance gets a warning at compile time that names the method to implement.
    ///
    /// - Warning: A conformance that implements neither this method nor `resource(for:)` also
    ///   compiles with only that warning, and then each default calls the other, so the first
    ///   call recurses until the stack overflows.
    ///
    /// - Parameter identifier: The identifier of the item to retrieve.
    /// - Returns: Whatever the conformance's `resource(for:)` returns.
    /// - Throws: Whatever the conformance's `resource(for:)` throws.
    @available(*, deprecated, message: "Implement item(for:) in this conformance. The default calls resource(for:), and it is removed in 8.0.0.")
    public func item(for identifier: Item.ID) async throws -> Item? {
        try await resource(for: identifier)
    }

    /// Calls `reset()`, for a conformance written against 6.0.0.
    ///
    /// Such a conformance implements `reset()` and not this method. This default lets it compile,
    /// and lets a caller of the new name reach its implementation. It is deprecated, so the
    /// conformance gets a warning at compile time that names the method to implement.
    ///
    /// - Warning: A conformance that implements neither this method nor `reset()` also compiles
    ///   with only that warning, and then each default calls the other, so the first call
    ///   recurses until the stack overflows.
    ///
    /// - Throws: Whatever the conformance's `reset()` throws.
    @available(*, deprecated, message: "Implement removeAll() in this conformance. The default calls reset(), and it is removed in 8.0.0.")
    public func removeAll() async throws {
        try await reset()
    }
}

extension Expiry {

    /// An expiry at the given instant: ``at(_:)``.
    ///
    /// In 6.0.0 `custom` was a case of ``Expiry``, and it is now ``at(_:)``. This function keeps an
    /// expression that builds one, such as `.custom(date)`, compiling. A pattern cannot call a
    /// function, so `case .custom(let date)` in a `switch` or an `if case` no longer compiles; match
    /// ``at(_:)`` there instead.
    ///
    /// - Parameter date: The instant at which the entry stops being served.
    /// - Returns: `.at(date)`.
    @available(*, deprecated, renamed: "at(_:)", message: "Use at(_:). custom(_:) is removed in 8.0.0.")
    public static func custom(_ date: Date) -> Expiry {
        .at(date)
    }
}

extension FileSystemCache {

    /// Creates a new file system–backed cache below a `FileSystemDirectory` from the `Files`
    /// package.
    ///
    /// 6.0.0 took a `FileSystemDirectory` here. An adopter cannot name that type without importing
    /// `Files`, and under member import visibility (SE-0444) cannot pass one of its cases with a
    /// leading dot without importing it either. ``init(_:subfolder:)-(CacheDirectory,_)`` takes a
    /// ``CacheDirectory``, declared in this package, and each of its cases resolves to the same
    /// directory as the `FileSystemDirectory` case of the same name, so a cache built either way
    /// reads and writes in the same place.
    ///
    /// A call that names the directory with a leading dot, such as `FileSystemCache(.caches)`,
    /// already resolves to the ``CacheDirectory`` initialiser, so it needs no change and raises no
    /// warning. This initialiser is marked as the less preferred overload for exactly that reason:
    /// without it, such a call would match both initialisers and stop compiling. Only a call that
    /// passes a `FileSystemDirectory` value reaches this one.
    ///
    /// - Parameters:
    ///   - fileSystemDirectory: The root directory in which resources will be stored.
    ///   - subfolder: An optional path below `fileSystemDirectory` used to scope the cache
    ///     contents. Defaults to `nil`.
    @available(*, deprecated, message: "Pass a CacheDirectory instead, such as FileSystemCache(CacheDirectory.caches, subfolder:). Each case names the same directory as the FileSystemDirectory case of the same name. This initialiser is removed in 8.0.0.")
    @_disfavoredOverload
    public init(
        _ fileSystemDirectory: FileSystemDirectory,
        subfolder: String? = nil
    ) {
        self.init(fileSystemDirectory: fileSystemDirectory, subfolder: subfolder)
    }
}
