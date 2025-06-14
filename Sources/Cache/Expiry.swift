//
//  Expiry.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A representation of time, indicating if a resource will be available locally at time of fetch.
public enum Expiry {
    
    // 1 minute
    case short
    // 3 minutes
    case medium
    // 1 hour
    case long
    // Any date specified.
    case custom(Date)

    var date: Date {
        switch self {
        case .short: return TimeInterval(60 * 1).date
        case .medium: return TimeInterval(60 * 3).date
        case .long: return TimeInterval(60 * 60).date
        case .custom(let date): return date
        }
    }
}

private extension TimeInterval {
    
    var date: Date {
        Date().addingTimeInterval(self)
    }
}
