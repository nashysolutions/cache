# FileSystemCache

`FileSystemCache` is a disk-backed cache implementation in the `Cache` library that stores Codable resources in the file system. It provides persistence across application launches and can be used to cache data in a way that survives app terminations and restarts.

---

Unlike `VolatileCache`, which only stores items in memory, `FileSystemCache` saves resources to disk using a directory structure you define. It supports both short-lived and long-lived expiry strategies and conforms to the same `Cache` protocol.

This makes it easy to substitute either implementation at runtime or for testing.

---

## Example

```swift
let cache = try FileSystemCache<MyModel>(
    directory: .caches,
    subfolder: "example"
)

let model = MyModel(id: "123", name: "Cached Item")
try await cache.stash(model, duration: .custom(.distantFuture))

let result = try await cache.resource(for: "123")
```

---

## Directory Configuration

`FileSystemCache` uses a `FileSystemDirectory` value to specify the root location:

```swift
enum FileSystemDirectory {
    case documents
    case caches
    case temporary
}
```

You can also pass a subfolder name to further scope your cache:

```swift
FileSystemCache(directory: .caches, subfolder: "game")
```

---

## Expiry Support

Like all cache types, `FileSystemCache` supports expiry policies:

```swift
try await cache.stash(item, duration: .short)                  // short-lived
try await cache.stash(item, duration: .custom(Date()))         // expires at a specific time
```

If a resource has expired, it will not be returned, and may be cleaned up later.

---

## Codable Support

Items must conform to both `Identifiable` and `Codable`. The `id` is used as the filename, and the item is encoded to JSON or another internal format.

---

## Error Handling

Because file system operations can fail, all public APIs on `FileSystemCache` are `async throws`.

Errors you may encounter include:

- Invalid path creation
- Encoding or decoding failures
- Read/write permissions
- Missing files

Handle errors explicitly:

```swift
do {
    try await cache.stash(item, duration: .short)
} catch {
    logger.error("Cache write failed: \(error)")
}
```

---

## When to Use

Use `FileSystemCache` when you need:

- Offline persistence of data
- Caching across app launches
- File-backed fallback for expensive computations or API responses

For ephemeral, non-critical, or short-lived data, prefer `VolatileCache`.

---

## Related Articles

- <doc:VolatileCache>
- <doc:Expiry>
- <doc:ErrorHandling>
