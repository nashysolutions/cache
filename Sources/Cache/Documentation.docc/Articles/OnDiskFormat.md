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

- `<base>` is the directory named by the ``CacheDirectory`` you pass to the initialiser. The
  deprecated initialiser that takes a `FileSystemDirectory` resolves each case to the same
  directory, so the layout does not depend on which initialiser built the cache.
- `<subfolder>` is the optional subfolder you pass, and is omitted when it is `nil`. It may be
  nested, and it must stay inside `<base>`, as the next section describes.
- `cache-v2` is chosen by this package and identifies the layout version.
- `<type>` is the lowercase hexadecimal SHA-256 digest of `Item`'s fully qualified name, and is
  what keeps two caches over different item types from reaching each other.
- `<digest>` is the same digest of the item identifier's `description`.
- `.cache` is the entry extension.

That is why ``FileSystemCache`` requires `Item.ID` to be `CustomStringConvertible`. The
identifier's `description` names its file, so it must be the same on every launch, or an entry
written on one launch is not found on the next, and different for different identifiers, or two
items share one file and each overwrites the other. `UUID`, `String` and the integer types meet
both conditions. Nothing checks either one for you.

The file body is the item and its expiry, encoded with a default `JSONEncoder` as a JSON object
with exactly two keys:

```json
{ "item": { … }, "expiry": 774835200.0 }
```

`expiry` uses `JSONEncoder`'s default date strategy, so it is a number of seconds since the
reference date of 1 January 2001, not a Unix timestamp. If you read these files with other
tooling, decode dates accordingly.

An entry is written atomically. Its bytes go to a temporary file in the same folder, which is
then renamed over the entry's filename, so a read never finds a partly written entry under that
name. If the process ends during a write, the temporary file can be left in the folder. Its name is
not an entry's name, so it is never read as an entry, and `removeAll()` and `removeExpired()`
leave it where it is.

## Where a subfolder may lead

Apart from `<base>` itself, which every operation creates if it is missing, everything the cache
creates, writes and deletes is inside `<base>`. A subfolder is joined to `<base>` as written, so
without a check `"../Documents"` would put the cache in the directory beside it. Every operation
therefore checks the folder it is about to use, before creating anything below `<base>`, and
refuses one that resolves outside `<base>` by throwing `CocoaError.fileWriteInvalidFileName`. The
error's `url` is the folder's location, as joined before anything is resolved. Nothing is created
or written below `<base>` when that happens, and the cache itself is unaffected: the initialiser
still cannot fail, and the next operation checks again.

The folder is refused when:

- the subfolder has a `..` component, wherever it would lead;
- the folder is not inside `<base>` once every symbolic link in either is followed;
- the folder passes through a symbolic link that cannot be followed, because its target is missing
  or it loops.

The check covers the whole folder, including the `cache-v2` and `<type>` components, so a link in
place of either is caught too.

These are accepted:

| Subfolder | Folder |
| --- | --- |
| `nil`, `""` or `"."` | `<base>/cache-v2/<type>` |
| `"a"` | `<base>/a/cache-v2/<type>` |
| `"a/b"` | `<base>/a/b/cache-v2/<type>` |
| `"/a"` | `<base>/a/cache-v2/<type>`, because a leading `/` is a separator, not the root |
| a link inside `<base>` to a folder inside `<base>` | wherever the link leads |

`..` is refused even where it would stay inside, as in `"a/../b"`. After a symbolic link, `..`
climbs from the link's target rather than from the link, so `"link/../x"` lands beside wherever
`link` points, while resolving the same text without the file system places it at `<base>/x`.
Refusing the component outright is what keeps the check exact.

The check is made by each operation rather than once, because a link that is not there when a
cache is created can be there by the time it is used. It is still a check made before the
operation rather than a lock held during it, so a link created inside `<base>` between the two is
not seen. Creating one needs write access to `<base>`, which is already enough to replace anything
the cache keeps there.

Following links needs the real file system. If you supply your own `fileSystemResourceClient`
whose locations are not on the real file system, nothing resolves, and the folder and `<base>` are
compared as written.

## A link at an entry's filename

The check above covers the folder, not each entry inside it. If a symbolic link sits at an entry's
own filename, no operation follows it:

- `setItem(_:expiry:)` replaces the link with the entry, and writes nothing where the link points.
- Reading the identifier reports `nil` and deletes the link, as it does for an entry that does not
  decode. What the link points to is not read.
- `removeItem(for:)` deletes the link, not what it points to.
- `removeAll()` and `removeExpired()` delete only regular files, so they leave the link in place.

The write needs no check to do this, because renaming a file over a link replaces the link rather
than following it. The read does need one, and like the folder check it is made before the read
rather than held during it, so a link created between the two is followed. Creating one needs
write access to the folder, which is already enough to replace the entry itself.

If you supply your own `fileSystemResourceClient`, its context is asked to write each entry with
the `.atomic` option, and the write replaces a link only if the context honours it. The read's
check asks the real file system, so for locations that are not on it, nothing is a link.

## What `removeAll()` deletes

`removeAll()` deletes files inside this cache's own `<type>` folder whose names are a lowercase
SHA-256 digest carrying the `.cache` extension. It does not delete directories, and it does not
delete anything else in the folder, including a file you placed inside it yourself.

It does not reach another item type's entries either. Before the `<type>` component existed, it
did: `removeAll()` on a `FileSystemCache<Alpha>` cleared every entry a `FileSystemCache<Beta>` had
written to the same directory.

In 6.0.0 and earlier this was not true: `reset()`, as `removeAll()` was then named, deleted the
directory the cache lived in. With the default `subfolder: nil` that directory was the base
directory, so calling `reset()` on a cache created as `FileSystemCache<Cheese>(.documents)` removed
the app's entire `Documents` directory.

## What `removeExpired()` deletes

`removeExpired()` deletes files in the same place, by the same name test, with one more condition:
the `expiry` the file carries precedes the moment the sweep began. It reports how many it deleted.

Only the `expiry` is decoded to decide that, not the item. An entry whose item no longer decodes
is therefore swept if it has expired. That is the common case after an app update changes the
item's shape: every entry the previous version wrote stops decoding, the read path described
below clears one only when its identifier is looked up again, and after an update it may never
be. An entry whose `expiry` cannot be read either, such as an empty file, is left in place and
not counted, because nothing says it has expired; the next lookup of its identifier clears it.

Like `removeAll()`, it does not reach another item type's entries, a file you placed in the folder
yourself, or anything written by an earlier layout.

The sweep is not transactional. If deleting one entry fails, the error is thrown, and the entries
deleted before it stay deleted.

## Entries that stop decoding

An entry's body is readable only while the item's `Codable` shape still matches the shape that
wrote it. Shipping an app update that renames a property, or adds a non-optional one, makes every
entry written by the previous version undecodable.

Such an entry is treated as a miss: reading its identifier reports `nil`, and the entry is deleted
on that read. An empty entry is treated the same way. Nothing is reported to the caller, because
there is nothing a caller can do with a payload that will never decode again, and leaving it in
place would strand it on disk indefinitely.

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

Removal does not depend on decoding either. `removeItem(for:)` deletes by the filename the
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
