//
//  PinnedNow.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Foundation

/// The instant the cache-level suites pin `\.date` to.
///
/// Both caches read the current time from `@Dependency(\.date)`, which has no test value, so a
/// test that sets, looks up or sweeps without overriding it reads the real clock and records an
/// issue. Every such suite therefore pins it to this instant, and writes its expiries relative to
/// it, so whether an entry has expired never depends on when the suite runs.
///
/// It is the instant ``VolatileStorageTests`` judges against, so the storage and cache suites
/// describe the same moment.
let pinnedNow = Date(timeIntervalSinceReferenceDate: 1_000_000)
