# Cache

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Fcache%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/nashysolutions/cache)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Fcache%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/nashysolutions/cache)

**Cache** is a Swift library for caching `Identifiable` values with optional expiry logic. It supports both **in-memory** and **file-backed** storage, making it suitable for short-lived data, offline persistence, or resource caching. The API is designed around Swift Concurrency, using `async`/`await` and Sendable-safe abstractions to support safe use in concurrent environments.

---

## Features

- ✅ Type-safe caching for any `Identifiable` type
- 📦 Two interchangeable storage implementations:
  - `VolatileCache`: fast in-memory storage
  - `FileSystemCache`: persistent, file-backed storage
- 💡 Built-in expiry support with predefined and custom durations
- 🧪 Testable without delays (no need for `sleep`)
- 🕹 Native async/await support. Designed for concurrent use with Sendable-safe public APIs
- 🧩 Easily injectable via `swift-dependencies`

---

## When Should I Use This?

Use this library when you want explicit, pull-based caching where refreshes happen only when requested by the caller, rather than being driven by background tasks or heuristics.

## Usage

See the **Quick Start** guide in the `Documentation.docc` catalogue.

### Example

```swift
struct Cheese: Identifiable, Sendable {
    let id: UUID
    let name: String
}

let cache = VolatileCache<Cheese>()
try await cache.stash(
    Cheese(id: UUID(), name: "Brie"),
    duration: .short
)
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
    static let liveValue: any Cache<Cheese> =
        FileSystemCache(.caches, subfolder: "Cheeses")
}
```

Then use it like this:

```swift
struct MyModel {

    @Dependency(\.cheeseCache) var cheeseCache

    func loadCheese(id: UUID) async throws -> Cheese? {
        try await cheeseCache.resource(for: id)
    }
}
```

For previews or tests:

```swift
#Preview {
    withDependencies {
        $0.cheeseCache = VolatileCache<Cheese>()
    } operation: {
        ContentView()
    }

}
```

## Design Principles

This library is intentionally small and opinionated. Its design is guided by the following principles:

### Determinism over cleverness
Cache behaviour should be predictable. Given the same identifier and storage, lookups should always resolve to the same resource or fail clearly. Silent fallbacks and non-deterministic behaviour are avoided.

### Explicit expiry
Expiry is a first-class concern and is modelled explicitly. Time-based behaviour is injected and testable, avoiding reliance on timers or `sleep` in tests.

### Type safety first
The API is generic over `Identifiable` types and encourages the use of strongly-typed identifiers (e.g. via `Tagged`) to prevent accidental ID mix-ups across domains.

### Storage as an implementation detail
In-memory and file-backed caches share the same interface and semantics. Consumers should not need to care *how* something is cached, only *that* it is cached.

### Fail fast on invalid state
Invariant violations (e.g. non-deterministic identifiers or invalid internal state) are treated as programmer errors and fail immediately rather than risking silent data corruption.

### Composable, not magical
The library avoids global state, hidden background work, and implicit behaviour. It is designed to compose cleanly with dependency injection systems such as `swift-dependencies`.

## Typed Identifiers (Recommended)

This library pairs particularly well with [Tagged](https://github.com/pointfreeco/swift-tagged).

Using plain `UUID` or `String` identifiers makes it easy to accidentally mix IDs between different models. Tagged allows you to create type-safe identifiers, preventing an entire class of subtle bugs.

Instead of this:

```swift
struct Fruit: Identifiable, Sendable {
    let id: UUID
    let name: String
}

func loadCheese(id: UUID) async throws -> Cheese? {
    try await cheeseCache.resource(for: id)
}
```

You can write this 

```swift
import Tagged

struct Fruit: Identifiable, Sendable {
    let id: Id
    let name: String
    
    typealias Id = Tagged<Fruit, UUID>
}

struct Cheese: Identifiable, Sendable {
    let id: Id
    let name: String
    
    typealias Id = Tagged<Cheese, UUID>
}

func loadCheese(id: Cheese.Id) async throws -> Cheese? {
    try await cheeseCache.resource(for: id)
}
```

The compiler now prevents you from passing a Fruit.Id where a Cheese.Id is expected, giving stronger guarantees and clearer intent throughout your codebase.
