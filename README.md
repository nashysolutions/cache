# Cache

![iOS](https://img.shields.io/badge/iOS-9%2B-blue)
![macOS](https://img.shields.io/badge/macOS-10.10%2B-blue)

Hold values or objects in volatile memory for a pre-determined amount of time.

### Usage

Stash a resource against an instance of `UUID`.

```swift
let cache = Cache<UIImage>()
cache.stash(image, with: id, duration: .short)

// retrieve using the same `id` value.
let image: UIImage? = cache.resource(for: id)
```

## Installation

Use the [Swift Package Manager](https://github.com/apple/swift-package-manager/tree/master/Documentation).
See [Releases](https://github.com/nashysolutions/Cache/releases).
