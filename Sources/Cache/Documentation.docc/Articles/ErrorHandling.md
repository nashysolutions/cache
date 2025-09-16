# ErrorHandling

Most cache operations in the library are marked as `async throws`:

```swift
func stash(_ item: Item, duration: Expiry) async throws
func resource(for id: Item.ID) async throws -> Item?
```

This applies to both `FileSystemCache` and `VolatileCache`, though the reasons for failure differ depending on the implementation.

---

## FileSystemCache Errors

`FileSystemCache` may throw for:

- Invalid file paths or directory creation
- Permission errors
- I/O failures while writing or reading
- Encoding or decoding failures (when saving `Codable` types)

Example:

```swift
do {
    try await fileCache.stash(item, duration: .short)
} catch {
    logger.error("Failed to write to cache: \(error)")
}
```

---

## VolatileCache and Throws

By default, `VolatileCache` does **not** throw internally.

However, due to the protocol-based nature of the `Cache` interface (`any Cache<T>`), calling methods on a cache value may still require `try`:

```swift
let result = try await volatileCache.resource(for: id)
```

This allows `VolatileCache` and `FileSystemCache` to be used interchangeably behind a protocol existential.

---

## Optional Access

If caching is non-critical, it's valid to ignore errors or suppress them optionally:

```swift
_ = try? await cache.stash(item, duration: .short)
```

---

## Recommendations

- Use `do-catch` for production-critical cache paths
- Use `try?` for performance optimisations, fallback caches, or UI-layer storage
- Ensure all cached types conform reliably to `Codable` if using `FileSystemCache`

---

## Related Articles

- <doc:FileSystemCache>
- <doc:VolatileCache>
- <doc:DependencyInjection>
