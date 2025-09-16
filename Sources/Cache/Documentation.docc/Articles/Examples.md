# Examples

Practical examples of using the `Cache` library with both `VolatileCache` and `FileSystemCache`, covering common operations such as storing, retrieving, injecting, and testing cached values.

---

Here is a cheat sheet of common use cases.

## Basic Caching with VolatileCache

```swift
let cache = VolatileCache<MyModel>()

let model = MyModel(id: "123", name: "Example")
try await cache.stash(model, duration: .short)

let result = try await cache.resource(for: "123")
```

---

## Persistent Caching with FileSystemCache

```swift
let cache = try FileSystemCache<MyModel>(
    directory: .caches,
    subfolder: "models"
)

let item = MyModel(id: "abc", name: "Disk-backed")
try await cache.stash(item, duration: .custom(.distantFuture))

let loaded = try await cache.resource(for: "abc")
```

---

## Injecting a Cache Using the dependencies library

 [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) library.

```swift
import Dependencies
import Cache

extension DependencyValues {
    var sportCache: any Cache<Sport> {
        get { self[SportCacheKey.self] }
        set { self[SportCacheKey.self] = newValue }
    }
}

private enum SportCacheKey: DependencyKey {
    static let liveValue: any Cache<Sport> = try! FileSystemCache(
        directory: .caches,
        subfolder: "sports"
    )
}

struct Sport: Identifiable, Codable {
    let type: String
    var id: String { type }
}

struct SportManager {
    @Dependency(\.sportCache) var sportCache

    func storeSport() async throws {
        let sport = Sport(type: "Football")
        try await sportCache.stash(sport, duration: .short)
    }
}
```

---

## Related Articles

- <doc:DependencyInjection>
- <doc:FileSystemCache>
- <doc:VolatileCache>
