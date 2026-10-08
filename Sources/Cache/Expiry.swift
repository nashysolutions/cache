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

    /// Indicates a long-lived resource, valid for exactly **1 hour** (3600 seconds) from the
    /// moment it is stashed.
    case long

    /// Indicates a custom expiration date.
    ///
    /// - Parameter date: The explicit `Date` at which the resource should expire.
    case custom(Date)

    /// Computes the absolute expiry `Date` using the provided base time.
    ///
    /// - Parameter now: The reference time from which to compute expiry.
    ///   Defaults to the current date and time.
    ///
    /// - Returns: A `Date` representing the exact expiration time.
    func date(using now: Date = Date()) -> Date {
        switch self {
        case .short: return now.addingTimeInterval(60 * 1)
        case .long: return now.addingTimeInterval(60 * 60)
        case .custom(let date): return date
        }
    }
}
