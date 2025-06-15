# VolatileCache

`VolatileCache` is an in-memory cache implementation included in the `Cache` library. It is designed for fast, ephemeral data storage that does not persist across application launches.

---

Unlike `FileSystemCache`, which stores data on disk, `VolatileCache` keeps all resources in memory. It is ideal for transient data, view model caching, or short-lived computed results.

It conforms to the same `Cache` protocol, making it interchangeable with other cache types.

---

## Example

```swift
let cache = VolatileCache<MyModel>()

let model = MyModel(id: "abc", name: "Transient")
try await cache.stash(model, duration: .short)

let result = try await cache.resource(for: "abc")
```

---

## Expiry Support

Like all cache types in this library, `VolatileCache` supports expiry policies:

```swift
try await cache.stash(item, duration: .custom(Date().addingTimeInterval(30)))
```

Resources that have passed their expiry date are automatically excluded from reads and may be purged in future iterations.

---

## Thread Safety

`VolatileCache` is actor-isolated and safe for use in concurrent Swift contexts. Operations are serialised internally to avoid race conditions.

---

## Performance

Because data is stored in memory, operations are extremely fast. However, resources are lost when the app terminates or the cache instance is deallocated.

This makes `VolatileCache` unsuitable for offline persistence but ideal for UI-layer caching.

---

## Error Handling

By default, `VolatileCache` is non-throwing. However, when accessed through an existential type like `any Cache<T>`, you may still need to use `try` due to protocol constraints.

```swift
_ = try? await cache.resource(for: id)
```

---

## When to Use

Use `VolatileCache` when you need:

- Fast in-memory access
- No persistence across launches
- Temporary storage for previews, view models, or computed values
- Lightweight test-time implementations

For persistent caching, consider `FileSystemCache`.

---

## Related Articles

- <doc:FileSystemCache>
- <doc:Expiry>
- <doc:TestingExpiry>
