# Cache

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Fcache%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/nashysolutions/cache)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Fcache%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/nashysolutions/cache)

**Cache** is a Swift library for caching `Identifiable` values with optional expiry logic. It supports both **in-memory** and **file-backed** storage, making it suitable for short-lived data, offline persistence, or resource caching.

---

## Features

- ✅ Type-safe caching for any `Identifiable` type
- 📦 Two interchangeable storage implementations:
  - `VolatileCache`: fast in-memory storage
  - `FileSystemCache`: persistent, file-backed storage
- 💡 Expiry support: `.short` or `.custom(Date)`
- 🧪 Testable without delays (no need for `sleep`)
- 🕹 Native async/await support. Fully thread safe and sendable.
- 🧩 Easily injectable via `swift-dependencies`

---

## Usage

See the QuickStart guide in the `Documentation.docc` catalogue.

### Example

```swift
struct Cheese: Identifiable {
    let id: Int
    let name: String
}

let cache = VolatileCache<Cheese>()
try await cache.stash(Cheese(id: 0, name: "Brie"), duration: .short)
```

---

### Dependency Injection

An example using [`swift-dependencies`](https://github.com/pointfreeco/swift-dependencies).

```swift
import Dependencies
import Cache

extension DependencyValues {

    /// A cache for storing and retrieving `Cheese` models.
    var cheeseCache: any Cache<Cheese> {
        get { self[CheeseCacheKey.self] }
        set { self[CheeseCacheKey.self] = newValue }
    }
}

private enum CheeseCacheKey: DependencyKey {
    static let liveValue: any Cache<Cheese> = FileSystemCache(.caches, subfolder: "Cheeses")
}
```

Then use it like this:

```swift
@Dependency(\.cheeseCache) var cheeseCache
let cheese = try await cheeseCache.resource(for: id)
```
