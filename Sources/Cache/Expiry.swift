//
//  Expiry.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A representation of expiration policy, indicating how long a resource should be considered valid.
///
/// `Expiry` provides a way to express short-lived or long-lived local validity for cached or stored resources.
/// It can be used to determine whether a resource is stale or still usable at the time of fetch.
///
/// This is typically used in cache management or offline resource fetching systems.
public enum Expiry: Sendable {
    
    /// Indicates a short-lived resource, valid for exactly **1 minute** (60 seconds) from the
    /// moment it is stashed.
    case short

    /// Indicates a medium-lived resource, valid for exactly **3 minutes** (180 seconds) from the
    /// moment it is stashed.
    case medium

    /// Indicates a long-lived resource, valid for exactly **1 hour** (3600 seconds) from the
    /// moment it is stashed.
    case long

    /// Indicates a custom expiration date.
    ///
    /// - Parameter date: The explicit `Date` at which the resource should expire.
    case custom(Date)

    /// Computes the absolute expiry `Date` using the provided base time.
    ///
    /// The base time has no default. Each cache passes the time it read from
    /// `@Dependency(\.date)`, and a default would be a way to read the wall clock that bypasses
    /// that dependency, so a test that pinned the time would no longer govern expiry.
    ///
    /// - Parameter now: The moment the item is stashed, from which a preset is counted. A custom
    ///   expiry ignores it.
    ///
    /// - Returns: A `Date` representing the exact expiration time.
    func date(using now: Date) -> Date {
        switch self {
        case .short: return now.addingTimeInterval(60 * 1)
        case .medium: return now.addingTimeInterval(60 * 3)
        case .long: return now.addingTimeInterval(60 * 60)
        case .custom(let date): return date
        }
    }
}
