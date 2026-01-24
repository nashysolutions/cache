# Cache

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Fcache%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/nashysolutions/cache)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Fcache%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/nashysolutions/cache)

A small, opinionated Swift cache for **predictable, testable, pull-based caching**.

Designed for production iOS apps where correctness, determinism, and clarity matter more than clever eviction strategies.

[Documentation](https://swiftpackageindex.com/nashysolutions/cache/main/documentation/cache)

---

## Why this exists

In production iOS apps, caching sits on the critical path between data correctness and user trust.

Over time, I noticed that many caching approaches optimise for convenience or automation at the expense of clarity: background refreshes, implicit invalidation, and time-based heuristics that make behaviour hard to predict or test.

This library is a deliberate response to that trade-off.

It is designed around a small set of constraints:

- Caching should be **explicit**
- Expiry should be **modelled, not inferred**
- Behaviour should be **deterministic and testable**
- Storage should remain an **implementation detail**

You ask for a resource.  
You either get it — or you don’t.

---

## What it is

- A generic cache for any `Identifiable & Sendable` type
- Two interchangeable backends:
  - `VolatileCache` — fast, in-memory
  - `FileSystemCache` — persistent, file-backed
- First-class expiry with injected time
- Native `async/await`
- Designed to compose cleanly with dependency injection

---

## What it deliberately avoids

- Background refresh loops
- Global singletons
- Heuristic eviction
- Non-deterministic behaviour
- “Helpful” fallbacks that hide bugs

If something is missing or expired, the cache tells you clearly.

---

## Example

```swift
struct Cheese: Identifiable, Sendable {
    let id: String
    let name: String
}

let cache = VolatileCache<Cheese>()

try await cache.stash(
    Cheese(id: "123", name: "Brie"),
    duration: .short
)

let cheese = try await cache.resource(for: "123")
```
