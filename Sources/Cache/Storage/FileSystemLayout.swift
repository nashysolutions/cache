//
//  FileSystemLayout.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Foundation
import CryptoKit

/// The on-disk layout that ``FileSystemCache`` writes, and the rules for recognising it.
///
/// The layout carries a version in its path so that a change to filename derivation, or to the
/// record format, is visible on disk rather than silently stranding every existing entry. That
/// is what happened in 6.0.0, which moved filenames from the identifier's description to a
/// SHA-256 digest and left the earlier files unreadable, unexpirable and undeletable.
///
/// ## Shape
///
/// An entry lives at `<base>/[<subfolder>/]cache-v2/<type>/<digest>.cache`, where `<type>` is the
/// lowercase hexadecimal SHA-256 of the item type's fully qualified name and `<digest>` is the
/// same digest of the item identifier's description. The file itself is a `CodableResource`
/// encoded by ``makeEntryEncoder()``: a JSON object with exactly the keys `item` and `expiry`,
/// where `expiry` is a number of seconds since 1 January 2001.
///
/// ## Ownership
///
/// Two claims are available here and they are not the same claim, which is the distinction that
/// the `<type>` component exists to make true.
///
/// The folder component and the file extension are chosen by this package rather than by the
/// consumer, so a file matching both is one **this package** wrote. That alone is what an earlier
/// version of this layout established, and it is not enough. Two caches over different item types
/// sharing a directory are both this package, so each could recognise, overwrite and delete the
/// other's entries, and a `reset()` on either cleared both.
///
/// Scoping every entry under a digest of its item type makes the stronger claim true: a file
/// below `cache-v2/<type>/` was written by **a cache over that one item type**. That is the claim
/// the self-healing delete in ``FileSystemStorage`` relies on, because it deletes an entry it
/// cannot decode, and "cannot decode" is exactly what another type's entry looks like.
///
/// ## Entries written before this layout existed
///
/// They are left where they are. Nothing outside a type folder is ever deleted, including the
/// entries that versions up to and including 6.0.0 wrote directly into the consumer's own
/// directory.
///
/// Deleting them would need a way to tell them apart from the consumer's files, and the only
/// property available is the contents, which is not a provenance. An entry is a JSON object with
/// exactly the keys `item` and `expiry` and a numeric `expiry`, and so is any other TTL wrapper's
/// record, and so is a consumer's own `{"item":"milk","expiry":3}`. Matching on that shape and
/// deleting the match destroys the consumer's data, on a first install as readily as an upgrade,
/// because nothing on disk says whether an earlier version was ever here. So do not reintroduce
/// such a sweep. Orphaned entries occupying disk is the lesser fault, and it is the one this
/// package accepts.
///
/// The same applies to entries written by a build of `cache-v2` from before the `<type>`
/// component existed, which sat directly in `cache-v2/`. No release ever wrote them, so only a
/// machine built against unreleased `main` can hold any, and they are orphaned on the same terms.
enum FileSystemLayout {

    /// The folder, below any consumer-supplied subfolder, that holds the current layout.
    ///
    /// Change this whenever filename derivation or the record format changes **in a released
    /// version**, so that entries written by the previous version stay recognisable instead of
    /// becoming invisible.
    ///
    /// The qualifier is the whole of the rule. This folder protects entries that exist on a
    /// consumer's disk, and only a release can put them there. `cache-v2` was introduced and then
    /// reshaped, by adding the `<type>` component, entirely between releases: the newest release
    /// is 6.0.0, which predates this file. Bumping to a third version for that reshape would have
    /// announced a migration away from a layout nobody was ever shipped.
    static let versionFolderName = "cache-v2"

    /// The extension carried by every entry file in the current layout.
    static let entryFileExtension = "cache"

    /// Creates an encoder that writes the record format described above.
    ///
    /// Paired with ``makeEntryDecoder()``, and stated beside it so that whoever changes one is
    /// looking at the other. Both sides belong to this package: entries used to be written by
    /// `Files`, which meant the on-disk format was whatever that package's encoder happened to
    /// do, and this file documented that choice without owning it.
    ///
    /// - Returns: An encoder for an entry's payload.
    static func makeEntryEncoder() -> JSONEncoder {
        JSONEncoder()
    }

    /// Creates a decoder that reads the record format described above.
    ///
    /// - Returns: A decoder for an entry's payload.
    static func makeEntryDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    /// The path, relative to the base directory, that the current layout version occupies.
    ///
    /// This is the enclosing folder rather than the one entries are written to. Entries go below
    /// a type folder inside it; see ``typeScopedSubfolder(below:for:)``.
    ///
    /// - Parameter subfolder: The consumer-supplied subfolder, if any.
    /// - Returns: A subfolder path to hand to a file system store.
    static func versionedSubfolder(below subfolder: String?) -> String {
        guard let subfolder, subfolder.isEmpty == false else {
            return versionFolderName
        }
        return subfolder + "/" + versionFolderName
    }

    /// The path, relative to the base directory, that one item type's entries occupy.
    ///
    /// - Parameters:
    ///   - subfolder: The consumer-supplied subfolder, if any.
    ///   - itemType: The item type the cache stores.
    /// - Returns: A subfolder path to hand to a file system store.
    static func typeScopedSubfolder(below subfolder: String?, for itemType: Any.Type) -> String {
        versionedSubfolder(below: subfolder) + "/" + typeFolderName(for: itemType)
    }

    /// The folder name that scopes one item type's entries.
    ///
    /// ## Why the name is qualified
    ///
    /// It derives from `String(reflecting:)` rather than `String(describing:)`, because the
    /// latter does not identify a type. Measured on Swift 6.2.4: two distinct nested types,
    /// `Outer.Inner` and `OtherOuter.Inner`, both describe as `Inner`, so scoping by that would
    /// have reproduced the collision this component exists to remove. `String(reflecting:)`
    /// carries the module and the full nesting, giving `Probe.Outer.Inner` against
    /// `Probe.OtherOuter.Inner`, and it distinguishes generic arguments too.
    ///
    /// ## Why the name is hashed rather than used as-is
    ///
    /// A Swift type name is not a safe path component, and both ways it can fail were measured
    /// rather than supposed:
    ///
    /// - It can contain a path separator. Swift 6's raw identifiers make `` struct `Foo/Bar` ``
    ///   legal, and it reflects as `` Module.`Foo/Bar` ``. Used literally, that is a directory
    ///   boundary.
    /// - It is case-sensitive where the file system is not. `~/Library/Caches`, `TMPDIR` and the
    ///   startup volume are all case-insensitive on a default macOS install, so `Foo` and `foo`
    ///   in one module would share a folder.
    ///
    /// A digest has neither problem, is a fixed length, and is the same answer this package
    /// already reached for identifiers.
    ///
    /// ## What instability costs
    ///
    /// `String(reflecting:)` is not a stable format across toolchains, and a consumer renaming or
    /// moving their type changes it too. Either orphans a type folder. That is a miss and some
    /// leaked disk, not a loss: the entries are a cache, a miss is a correct outcome, and nothing
    /// deletes or overwrites anything it did not write. The same instability under the previous
    /// shared-folder layout produced mutual destruction rather than a miss, which is the reason
    /// this design tolerates it.
    ///
    /// - Parameter itemType: The item type the cache stores.
    /// - Returns: A lowercase SHA-256 digest, safe to use as a single path component.
    static func typeFolderName(for itemType: Any.Type) -> String {
        digest(of: String(reflecting: itemType))
    }

    /// The filename an identifier derives, carrying the entry extension.
    ///
    /// - Parameter identifier: The textual form of an item identifier.
    /// - Returns: A filename with no leading path.
    static func entryFilename(for identifier: String) -> String {
        digest(of: identifier) + "." + entryFileExtension
    }

    /// Whether a filename is one this package wrote in the current layout.
    ///
    /// - Parameter filename: A filename with no leading path.
    /// - Returns: `true` if the name is a lowercase SHA-256 digest carrying the entry extension.
    static func isEntryFilename(_ filename: String) -> Bool {

        guard filename.hasSuffix("." + entryFileExtension) else {
            return false
        }

        let digest = filename.dropLast(entryFileExtension.count + 1)

        guard digest.count == 64 else {
            return false
        }

        return digest.allSatisfy { character in
            character.isHexDigit && character.isUppercase == false
        }
    }

    /// Computes a file-system-safe name by hashing a string.
    ///
    /// The result is stable for the same input and avoids characters that may be invalid in
    /// filenames across platforms.
    ///
    /// - Important: This is not intended for security-sensitive uses like password hashing. It is
    ///   used purely to derive a deterministic, compact path component.
    /// - Parameter string: The text to hash.
    /// - Returns: A 64-character lowercase hex string of the SHA-256 digest.
    private static func digest(of string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
