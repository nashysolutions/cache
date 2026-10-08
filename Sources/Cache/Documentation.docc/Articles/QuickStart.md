# QuickStart

This article explains how to get started quickly.

## Overview

Your model must conform to `Identifiable` and `Sendable`. You have the option of a
``VolatileCache`` or a ``FileSystemCache``. If you choose ``FileSystemCache``, then your model must
also conform to `Codable`, and its `id` must conform to `CustomStringConvertible`, as `UUID`,
`String` and the integer types already do. Each entry on disk is named by a digest of the `id`'s
`description`, so that text must be the same on every launch and different for different
identifiers.

```swift
import Cache

struct Cheese: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
}
```

### VolatileCache

Instantiate your cache and use it.

```swift
let cache = VolatileCache<Cheese>()

try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

let brie = try await cache.item(for: 1)
```

There is no step 2.

### FileSystemCache

Instantiate your cache and use it.

```swift
let cache = FileSystemCache<Cheese>(.caches, subfolder: "Cheeses")

try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

let brie = try await cache.item(for: 1)
```

There is no step 2 here either. `.caches` is a ``CacheDirectory``, which this package declares,
so `import Cache` is the only import this needs. Entries are written to the real file system with
no further setup, into a versioned folder below the directory you nominate. See
<doc:OnDiskFormat> for the layout, and for what this package will and will not delete.

A lookup for an identifier you have not set reports `nil` rather than throwing, and so does an
entry whose stored payload no longer decodes. An error means the operation could not be completed:
a cache directory that cannot be created or searched, an entry that cannot be read, or a subfolder
that leads outside the directory you nominated, which every operation refuses. An
identifier the cache cannot look for is not the same as one it does not hold, so the first throws
and the second does not.

The initialiser touches no disk and cannot fail, so an unusable directory is reported by the first
operation that needs it, not by construction.

Two caches over different item types can share a directory without seeing each other; the
separation is in the path rather than in a convention, so neither can read, overwrite or clear the
other's entries.

> Important: on a non-sandboxed macOS process, `.documents` is the user's real `~/Documents`, and
> a cache nominating it creates a folder there on first use.

## Choosing an expiry

Every item is set with an ``Expiry``. ``Expiry/short``, ``Expiry/medium`` and ``Expiry/long`` last
one minute, three minutes and an hour from the moment the item is set. Any other length is a
`Duration`:

```swift
try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .after(.seconds(10 * 60)))
```

A fixed deadline is a `Date`, passed as `.at(date)`, and does not depend on when the item is set.
Setting an item under an identifier the cache already holds replaces that entry, expiry included.

## Clearing expired entries

An expired entry is removed when its identifier is next looked up. One that is never looked up
again stays where it is, which for a file-backed cache means it stays on disk. When you want them
gone, say so:

```swift
let removed = try await cache.removeExpired()
```

Every expired entry is removed and the count comes back. Nothing calls this for you: not a timer,
not a read, not a write. Launch, sign-out and a low-storage warning are the usual moments. Both
caches support it, and the result can be ignored.

## Controlling time

Both caches read the current time from `@Dependency(\.date)`, which comes from
[swift-dependencies](https://github.com/pointfreeco/swift-dependencies). Setting an item
counts its ``Expiry`` from that reading, and a lookup or a sweep judges the expiry against a fresh
one. An entry is served up to and including the instant it expires, and not after it.

To set the time, override `\.date` with `withDependencies`. A cache constructed inside such a scope
keeps that time for every later call made outside one, and a scope around a single call takes
precedence for that call.

```swift
import Cache
import Dependencies
import Foundation

let storedAt = Date(timeIntervalSince1970: 1_700_000_000)

let cache = withDependencies {
    $0.date.now = storedAt
} operation: {
    VolatileCache<Cheese>()
}

try await cache.setItem(Cheese(id: 1, name: "Brie"), expiry: .long)

let brie = try await withDependencies {
    $0.date.now = storedAt.addingTimeInterval(59 * 60)
} operation: {
    try await cache.item(for: 1)
}

let gone = try await withDependencies {
    $0.date.now = storedAt.addingTimeInterval(61 * 60)
} operation: {
    try await cache.item(for: 1)
}
```

`brie` is the cheese, 59 minutes into its hour, and `gone` is `nil`, a minute after the hour ran
out. Nothing waits in between.

In a test, override `\.date` for every cache that sets, looks up or sweeps. `swift-dependencies`
declares no test value for it, so a cache left on the default reads the real clock, and the read is
recorded as a test failure saying that `@Dependency(\.date)` has no test implementation. A preview
and a shipping app read the real clock, and record nothing.

## Supplying your own file system

Everything above uses `FileManager`. If you need something else, a stub for a test or a file
system of your own, supply a `FileSystemResourceClient` and construct the cache inside that scope.

```swift
import Cache
import Dependencies
import Files
import FoundationDependencies

let cache = withDependencies {
    $0.fileSystemResourceClient = FileSystemResourceClient { directory, subfolder in
        try FileSystemFolderStore(agent: myAgent, kind: directory, subfolder: subfolder)
    }
} operation: {
    FileSystemCache<Cheese>(.caches, subfolder: "Cheeses")
}
```

`myAgent` is any `FileSystemContext` from the [Files](https://github.com/nashysolutions/files)
library. The cache resolves its client when it is constructed, so it must be constructed inside
the `operation` closure, not merely used there.

## In a test, and in a preview

Neither a test run nor an Xcode preview reaches the real file system. In both, setting an item
succeeds, every lookup reports `nil` whatever you set first, no directory is created, and nothing
warns you.

The cause is the same in both cases. `swift-dependencies` resolves a *test* value inside a test
and a *preview* value inside a preview, and for `fileSystemResourceClient` both are witnessed in
`foundation-dependencies` as a mock that accepts writes and keeps nothing. Declaring a live value,
as this package does, does not displace either.

The preview case is the one that catches people out, because a preview is somewhere you build UI
rather than somewhere you opted into a harness.

Two ways out, and which you want depends on what you are doing:

- Supply your own client, as above. This is the right choice for a unit test, which should not be
  touching a real disk.
- Opt into the live context, which is the right choice for an integration test, or for a preview
  that means to exercise real storage. Point it at a directory you are willing to have written to.

```swift
let cache = withDependencies {
    $0.context = .live
} operation: {
    FileSystemCache<Cheese>(.temporary, subfolder: "CheeseTests")
}
```

## Upgrading

7.0.0 renamed the four operations every cache shares, so that each name says what the call does:
`stash(_:duration:)` is now ``Cache/setItem(_:expiry:)``, `resource(for:)` is ``Cache/item(for:)``,
`removeResource(for:)` is ``Cache/removeItem(for:)``, and `reset()` is ``Cache/removeAll()``.
``Expiry`` gained ``Expiry/after(_:)`` for a duration of any length, `custom(_:)` became
``Expiry/at(_:)``, and `.short`, `.medium` and `.long` read the same at the call site as before.

The old names still compile, each with a deprecation warning and a fix-it, until 8.0.0. So does a
`Cache` conformance of your own that implements the old names, and it is warned which new name to
implement. Two things stop compiling: a pattern such as `case .custom(let date)`, which matches
`.at` instead, and a `switch` over ``Expiry`` that lists the four 6.0.0 cases, which covers
`.after` and `.at` instead.

Earlier versions of this article asked you to write a `FileSystemContext` and two `@retroactive
DependencyKey` conformances by hand. That is no longer needed, and the conformance for
`FileSystemResourceClientKey` is now declared by this package, so a copy of it in your own code is
a duplicate and will not compile. Delete yours.

If you also wrote the `FileSystemClientKey` conformance, this package never read it. Keep it only
if something else in your app does.

``FileSystemCache`` used to take a `FileSystemDirectory` from the `Files` package, and now takes a
``CacheDirectory``. A call written with a leading dot, such as `FileSystemCache<Cheese>(.caches)`,
needs no change. Code that passes a `FileSystemDirectory` value still compiles, with a deprecation
warning, until 8.0.0; pass the ``CacheDirectory`` case of the same name instead, which names the
same directory, so entries already on disk are still found. If `Files` was imported only to name
the directory, that import can go.

To learn more about `liveValue` see the readme for [Pointfree's](https://www.pointfree.co) library
named [Dependencies](https://github.com/pointfreeco/swift-dependencies).
