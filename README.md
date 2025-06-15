# Cache

**Cache** is a Swift library for caching `Identifiable` values with optional expiry logic. It supports both **in-memory** and **file-backed** storage, making it suitable for short-lived data, offline persistence, or resource caching.

---

## Features

- ✅ Type-safe caching for any `Identifiable` type
- 📦 Two interchangeable storage implementations:
  - `VolatileCache`: fast in-memory storage
  - `FileSystemCache`: persistent, file-backed storage
- ⏱ Expiry support: `.short` or `.custom(Date)`
- 🧪 Testable without delays (no need for `sleep`)
- 🕹 Native async/await support. Fully thread safe and sendable.
- 🧩 Easily injectable via `swift-dependencies`

---

## Usage

### Volatile (in-memory) caching

```swift
let cache = VolatileCache<MyModel>()

try await cache.stash(MyModel(id: "a", name: "Temp"), duration: .short)

let item = try await cache.resource(for: "a")
```

### File-backed persistent caching

```swift
let cache = try FileSystemCache<MyModel>(directory: .caches, "games")

try await cache.stash(MyModel(id: "b", name: "something"), duration: .custom(.distantFuture))

let item = try await cache.resource(for: "b")
```

---

## Dependency Injection

If you're using [`swift-dependencies`](https://github.com/pointfreeco/swift-dependencies), you can expose your preferred cache type as a dependency:

```swift
import Dependencies
import Cache

extension DependencyValues {
    /// A cache for storing and retrieving `Sport` models.
    var sportCache: any Cache<Sport> {
        get { self[SportCacheKey.self] }
        set { self[SportCacheKey.self] = newValue }
    }
}

private enum SportCacheKey: DependencyKey {
    static let liveValue: any Cache<Sport> = FileSystemCache(
        directory: .caches,
        subfolder: "sports"
    )
}
```

Then use it like this:

```swift
@Dependency(\.sportCache) var sportCache
let sport = try await sportCache.resource(for: id)
```
