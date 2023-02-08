# Cache

![iOS](https://img.shields.io/badge/iOS-9%2B-blue)
![macOS](https://img.shields.io/badge/macOS-10.15%2B-blue)

Hold values or objects in volatile memory for a pre-determined amount of time.

### Usage

Stash a resource against an instance of `UUID`.

```swift
struct TestValue: Identifiable {
    let id: UUID
    let image: UIImage
}
let cache = Cache<TestValue>()
cache.stash(value, duration: .short)

// retrieve using the same `id` value.
let value: TestValue? = cache.resource(for: value.id)
```

## Installation

Use the [Swift Package Manager](https://github.com/apple/swift-package-manager/tree/master/Documentation).
See [Releases](https://github.com/nashysolutions/Cache/releases).
