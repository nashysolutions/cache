# ``Cache``

Provides a unified API for storing and retrieving `Identifiable` items with optional expiry, and is designed to be testable, composable, and concurrency-safe.

## Overview

`Cache` is a modular caching framework that supports:

- ⚡️ `VolatileCache` — in-memory, fast, ephemeral
- 💾 `FileSystemCache` — disk-backed, persistent, Codable
- 💡 `Expiry` policies to control item lifetime
- ✅ `Identifiable` and `Codable` data
- 🧪 test-friendly behaviour without needing `sleep`
- 🧩 seamless integration with `swift-dependencies`

## Versioning

`Cache` follows Semantic Versioning. A public symbol that is renamed or removed is deprecated in a minor release first, and removed only in the next major. See the [versioning policy](https://github.com/nashysolutions/cache/blob/main/CONTRIBUTING.md#versioning-policy).
