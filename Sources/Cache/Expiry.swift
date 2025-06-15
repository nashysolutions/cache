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
public enum Expiry {
    
    /// Indicates a short-lived resource, typically valid for **1 minute** from now.
    case short

    /// Indicates a medium-lived resource, typically valid for **3 minutes** from now.
    case medium

    /// Indicates a long-lived resource, typically valid for **1 hour** from now.
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
        case .medium: return now.addingTimeInterval(60 * 3)
        case .long: return now.addingTimeInterval(60 * 60)
        case .custom(let date): return date
        }
    }
}
