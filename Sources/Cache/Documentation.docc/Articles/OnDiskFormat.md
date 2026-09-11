# On-disk format

What ``FileSystemCache`` writes to disk, what it deletes, and what happens to entries written by an earlier version.

## Overview

A ``FileSystemCache`` shares a directory with whatever else you keep there. It therefore has to be
able to tell its own files apart from yours, and the layout exists to make that decidable rather
than guessed.

## Layout

An entry is written to:

```
<base>/[<subfolder>/]cache-v2/<type>/<digest>.cache
```

- `<base>` is the directory named by the `FileSystemDirectory` you pass to the initialiser.
- `<subfolder>` is the optional subfolder you pass, and is omitted when it is `nil`.
- `cache-v2` is chosen by this package and identifies the layout version.
- `<type>` is the lowercase hexadecimal SHA-256 digest of `Item`'s fully qualified name, and is
  what keeps two caches over different item types from reaching each other.
- `<digest>` is the same digest of the item identifier's description.
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

`reset()` deletes files inside this cache's own `<type>` folder whose names are a lowercase
SHA-256 digest carrying the `.cache` extension. It does not delete directories, and it does not
delete anything else in the folder, including a file you placed inside it yourself.

It does not reach another item type's entries either. Before the `<type>` component existed, it
did: `reset()` on a `FileSystemCache<Alpha>` cleared every entry a `FileSystemCache<Beta>` had
written to the same directory.

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
that will never decode again, and leaving it in place would strand it on disk indefinitely.

Deleting one of these is safe in a way that deleting an entry from an earlier layout is not,
which is why the section below reaches the opposite conclusion about those. The proof this delete
rests on has to be the strong one, and it is worth being exact about which claim is being made.

An entry inside `cache-v2` carrying a digest filename and the entry extension is provably one
**this package** wrote. That is not enough, because "does not decode" is also precisely what
another item type's entry looks like, so on that claim alone the delete cleared a different
cache's live data. An entry inside `cache-v2/<type>/` is provably one **a cache over that one
item type** wrote, which is the claim that makes an undecodable entry this cache's own litter,
and clearing it up not a guess about whose data it is.

An entry from an earlier layout offers neither proof.

Removal does not depend on decoding either. `removeResource(for:)` deletes by the filename the
identifier derives, so it never reads the entry first.

A failure to *read* an entry that is present, such as a permissions error, is a different matter
and is thrown rather than reported as a miss. The entry is left where it is.

## Entries written by an earlier version

Versions up to and including 6.0.0 wrote entries directly into `<base>/[<subfolder>/]`, with no
versioned folder and no extension. 6.0.0 additionally changed the filename from the identifier's
description to a SHA-256 digest, which left every entry written by 5.x unreachable: never read,
never expired, never removed.

**Those entries are left on disk, and this package will not remove them.** They are unreachable
from the cache itself, so they occupy that disk until something else clears it up. Deleting them
is your call, not this package's.

That is deliberate. Removing them automatically would need a way to tell one of them apart from a
file you put there yourself, and there is none. Their filenames are whatever the identifier's
description happened to be, so a filename check is a guess. Their contents are a JSON object with
exactly the keys `item` and `expiry` and a numeric `expiry`, which is also the shape of any other
TTL wrapper's record, and of a perfectly ordinary `{"item":"milk","expiry":3}` of your own. A
sweep matching on that shape deletes your data, and it cannot even limit the damage to upgrades:
nothing on disk records whether an earlier version was ever installed, so a first-time adopter's
directory is scanned and matched on the very first use.

The same applies, on the same terms, to entries written directly into `cache-v2/` by a build
made before the `<type>` component existed. No release ever wrote one: the newest release is
6.0.0, which predates the `cache-v2` layout entirely, so only a machine built against unreleased
`main` can be holding any.

To clear the old entries yourself, delete them by hand. With `subfolder: nil` they sit directly in
the base directory alongside the `cache-v2` folder; with a subfolder, directly inside it. A cache
configured with a subfolder is the easier one to tidy, which is a reason to prefer one.
