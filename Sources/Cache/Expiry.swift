//
//  Expiry.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// When a cached entry stops being served.
///
/// An expiry is either relative or absolute. ``after(_:)`` counts a `Duration` from the moment the
/// item is set, and ``at(_:)`` names the instant outright. ``short``, ``medium`` and ``long`` are
/// presets of ``after(_:)``.
///
/// In ``VolatileCache`` and ``FileSystemCache``, the moment an item is set is the time the cache
/// reads from `@Dependency(\.date)` when ``Cache/setItem(_:expiry:)`` is called, so a test that
/// pins that time governs every relative expiry. A conformance of your own decides where its time
/// comes from. An entry is served up to and including the instant it expires, and not after it.
///
/// Two expiries are equal when they state the same policy, not when they would resolve to the
/// same instant: `.after(.seconds(60))` equals `.after(.milliseconds(60_000))`, and never equals
/// an ``at(_:)``, whatever the date.
public enum Expiry: Sendable, Hashable {

    /// Expires once the given duration has passed, counted from the moment the item is set.
    ///
    /// A zero duration expires at the moment the item is set: a lookup at that same instant still
    /// serves it, and a lookup at any later instant does not. A negative duration expires before
    /// the item is set, so no lookup serves it, and the next ``Cache/removeExpired()`` removes it.
    case after(Duration)

    /// Expires at the given instant, whenever the item is set.
    ///
    /// The time the item is set plays no part, so a date already past when the item is set
    /// gives an entry that no lookup serves.
    case at(Date)

    /// Expires exactly **1 minute** (60 seconds) after the item is set.
    public static let short = Expiry.after(.seconds(60))

    /// Expires exactly **3 minutes** (180 seconds) after the item is set.
    public static let medium = Expiry.after(.seconds(180))

    /// Expires exactly **1 hour** (3600 seconds) after the item is set.
    public static let long = Expiry.after(.seconds(3600))

    /// Computes the absolute expiry `Date` using the provided base time.
    ///
    /// The base time has no default. Each cache passes the time it read from
    /// `@Dependency(\.date)`, and a default would be a way to read the wall clock that bypasses
    /// that dependency, so a test that pinned the time would no longer govern expiry.
    ///
    /// - Parameter now: The moment the item is set, from which ``after(_:)`` is counted. ``at(_:)``
    ///   ignores it.
    ///
    /// - Returns: A `Date` representing the exact expiration time.
    func date(using now: Date) -> Date {
        switch self {
        case .after(let duration): return now.addingTimeInterval(duration.timeInterval)
        case .at(let date): return date
        }
    }
}

private extension Duration {

    /// The duration as a `TimeInterval`, for `Date.addingTimeInterval(_:)`.
    ///
    /// The standard library has no conversion from `Duration` to `TimeInterval`. Dividing by one
    /// second converts every `Duration`. Adding up its `components` instead would trap once the
    /// whole seconds exceed `Int64.max`, which a `Duration` can hold. A `Date` is itself a
    /// `Double` interval, so the conversion loses no precision the `Date` would keep.
    var timeInterval: TimeInterval {
        self / .seconds(1)
    }
}
