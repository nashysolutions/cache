# On-disk format

What ``FileSystemCache`` writes to disk, what it deletes, and what happens to entries written by an earlier version.

## Overview

A ``FileSystemCache`` shares a directory with whatever else you keep there. It therefore has to be
able to tell its own files apart from yours, and the layout exists to make that decidable rather
than guessed.

## Layout

An entry is written to:

```
<base>/[<subfolder>/]cache-v2/<digest>.cache
```

- `<base>` is the directory named by the `FileSystemDirectory` you pass to the initialiser.
- `<subfolder>` is the optional subfolder you pass, and is omitted when it is `nil`.
- `cache-v2` is chosen by this package and identifies the layout version.
- `<digest>` is the lowercase hexadecimal SHA-256 digest of the item identifier's description.
- `.cache` is the entry extension.

The file body is a `CodableResource` encoded with a default `JSONEncoder`, which is a JSON object
with exactly two keys:

```json
{ "item": { … }, "expiry": 774835200.0 }
```

`expiry` uses `JSONEncoder`'s default date strategy, so it is a number of seconds since the
reference date of 1 January 2001, not a Unix timestamp. If you read these files with other
tooling, decode dates accordingly.

## What `reset()` deletes

`reset()` deletes files inside `cache-v2` whose names are a lowercase SHA-256 digest carrying the
`.cache` extension. It does not delete directories, and it does not delete anything else in the
folder, including a file you placed inside `cache-v2` yourself.

In 6.0.0 and earlier this was not true: `reset()` deleted the directory the cache lived in. With
the default `subfolder: nil` that directory was the base directory, so calling `reset()` on a
cache created as `FileSystemCache<Cheese>(.documents)` removed the app's entire `Documents`
directory.

## Entries that stop decoding

An entry's body is readable only while the item's `Codable` shape still matches the shape that
wrote it. Shipping an app update that renames a property, or adds a non-optional one, makes every
entry written by the previous version undecodable.

Such an entry is treated as a miss: reading its identifier reports `nil`, and the entry is deleted
on that read. An empty entry, which is what a truncated write leaves behind, is treated the same
way. Nothing is reported to the caller, because there is nothing a caller can do with a payload
that will never decode again, and leaving it in place would strand it on disk exactly as the 5.x
entries below were stranded.

Removal does not depend on decoding either. `removeResource(for:)` deletes by the filename the
identifier derives, so it never reads the entry first.

A failure to *read* an entry that is present, such as a permissions error, is a different matter
and is thrown rather than reported as a miss. The entry is left where it is.

## Entries written by an earlier version

Versions up to and including 6.0.0 wrote entries directly into `<base>/[<subfolder>/]`, with no
versioned folder and no extension. 6.0.0 additionally changed the filename from the identifier's
description to a SHA-256 digest, which left every entry written by 5.x unreachable: never read,
never expired, never removed.

On its first use, a cache now sweeps those entries away. Because their filenames are
indistinguishable from a file you put there yourself, the sweep identifies a candidate by reading
it: a file is deleted only when its contents decode as a JSON object whose keys are exactly `item`
and `expiry`, with `expiry` decodable as a date. Anything that fails that check is left alone, as
is any file too large to inspect.

Two consequences are worth knowing:

- **The cache starts cold after upgrading.** Entries written by 6.0.0 and earlier are discarded
  rather than migrated. A cold cache is a legitimate state for a cache; leaking that disk forever
  is not.
- **The sweep reads the directory you nominated.** The narrower that directory, the less work it
  is. A cache configured with a subfolder inspects only the subfolder; a cache configured with
  `subfolder: nil` inspects everything sitting directly in the base directory.
