# DependencyInjection

Learn how to integrate the `Cache` library with Pointfree's dependencies library.

---

This article demonstrates how to inject a cache (either `VolatileCache` or `FileSystemCache`) using the `@Dependency` property wrapper from the [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) library.

---

## Registering the Dependency

Extend `DependencyValues` and create a `DependencyKey` for your cache type.

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

---

## Defining the Model

```swift
struct Sport: Identifiable, Codable {
    let type: String
    var id: String { type }
}
```

---

## Using the Injected Cache

Use the `@Dependency` property wrapper to access your cache from anywhere in your code:

```swift
struct ExampleUsage {
    @Dependency(\.sportCache) var sportCache

    func cacheFootball() async throws {
        let football = Sport(type: "Football")
        try await sportCache.stash(football, duration: .short)
    }
}
```

## Related Articles

- <doc:FileSystemCache>
- <doc:VolatileCache>
- <doc:ErrorHandling>
