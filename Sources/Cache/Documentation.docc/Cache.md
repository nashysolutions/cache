# ``Cache``

**Cache** is a Swift package for managing in-memory and persistent data caching. It provides a unified API for storing and retrieving `Identifiable` items with optional expiry, and is designed to be testable, composable, and concurrency-safe.

---

`Cache` is a modular caching framework that supports:

- ⚡️ `VolatileCache` — in-memory, fast, ephemeral
- 💾 `FileSystemCache` — disk-backed, persistent, Codable
- ⏱ `Expiry` policies to control item lifetime
- ✅ `Identifiable` and `Codable` data
- 🧪 test-friendly behaviour without needing `sleep`
- 🧩 seamless integration with `swift-dependencies`

---

## Architecture

The library provides a protocol-oriented structure:

@Image(source: "1")

All cache types conform to a common `Cache` protocol. The backing store can be swapped or injected for testability.

---

## Quick Start

```swift
let cache = VolatileCache<MyModel>()
try await cache.stash(MyModel(id: "abc", name: "Cached"), duration: .short)
let item = try await cache.resource(for: "abc")
```

---

## Use Cases

- Offline-first storage of fetched models
- Caching view models or derived values
- Lightweight, memory-only session caches
- Testing resource expiry without real delay

---

## Dependency Injection

The cache can be easily used with [swift-dependencies](https://github.com/pointfreeco/swift-dependencies):

```swift
@Dependency(\.myModelCache) var cache
let result = try await cache.resource(for: id)
```

---

## Learn More

- <doc:VolatileCache>
- <doc:FileSystemCache>
- <doc:ErrorHandling>
- <doc:UsingWithDependencies>
- <doc:Examples>
