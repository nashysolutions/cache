# QuickStart

This article explains how to get started quickly.

## Overview

Your model must conform to `Identifiable` and `Sendable`, and its `id` must conform to
`LosslessStringConvertible`. You have the option of a ``VolatileCache`` or a ``FileSystemCache``.
If you choose ``FileSystemCache``, then your model must also conform to `Codable`.

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

try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)

let brie = try await cache.resource(for: 1)
```

There is no step 2.

### FileSystemCache

Instantiate your cache and use it.

```swift
let cache = FileSystemCache<Cheese>(.caches, subfolder: "Cheeses")

try await cache.stash(Cheese(id: 1, name: "Brie"), duration: .long)

let brie = try await cache.resource(for: 1)
```

There is no step 2 here either. Entries are written to the real file system with no further
setup, into a versioned folder below the directory you nominate. See <doc:OnDiskFormat> for the
layout, and for what this package will and will not delete.

A lookup for an identifier you have not stashed reports `nil` rather than throwing, and so does an
entry whose stored payload no longer decodes. An error means the operation could not be completed:
a cache directory that cannot be created or searched, or an entry that cannot be read. An
identifier the cache cannot look for is not the same as one it does not hold, so the first throws
and the second does not.

The initialiser touches no disk and cannot fail, so an unusable directory is reported by the first
operation that needs it, not by construction.

Two caches over different item types can share a directory without seeing each other; the
separation is in the path rather than in a convention, so neither can read, overwrite or clear the
other's entries.

> Important: on a non-sandboxed macOS process, `.documents` is the user's real `~/Documents`, and
> a cache nominating it creates a folder there on first use.

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

Neither a test run nor an Xcode preview reaches the real file system. In both, a `stash` succeeds,
every lookup reports `nil` whatever you stashed first, no directory is created, and nothing warns
you.

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

Earlier versions of this article asked you to write a `FileSystemContext` and two `@retroactive
DependencyKey` conformances by hand. That is no longer needed, and the conformance for
`FileSystemResourceClientKey` is now declared by this package, so a copy of it in your own code is
a duplicate and will not compile. Delete yours.

If you also wrote the `FileSystemClientKey` conformance, this package never read it. Keep it only
if something else in your app does.

To learn more about `liveValue` see the readme for [Pointfree's](https://www.pointfree.co) library
named [Dependencies](https://github.com/pointfreeco/swift-dependencies).
