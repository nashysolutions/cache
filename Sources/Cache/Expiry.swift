//
//  Expiry.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A representation of time, indicating if a resource will be available locally at time of fetch.
enum Expiry {
    
    // 1 minute
    case short
    // 3 minutes
    case medium
    // 1 hour
    case long
    // Any date specified.
    case custom(Date)

    /// Returns the absolute expiry `Date` based on the provided reference time.
    ///
    /// - Parameter now: The base time from which to calculate the expiry. Defaults to current time.
    /// - Returns: A `Date` representing the expiry deadline.
    func date(using now: Date = Date()) -> Date {
        switch self {
        case .short: return now.addingTimeInterval(60 * 1)
        case .medium: return now.addingTimeInterval(60 * 3)
        case .long: return now.addingTimeInterval(60 * 60)
        case .custom(let date): return date
        }
    }
}
