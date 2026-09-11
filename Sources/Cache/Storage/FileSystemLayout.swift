//
//  FileSystemLayout.swift
//  cache
//
//  Created by Robert Nash on 11/09/2026.
//

import Foundation

/// The on-disk layout that ``FileSystemCache`` writes, and the rules for recognising it.
///
/// The layout carries a version in its path so that a change to filename derivation, or to the
/// record format, is visible on disk rather than silently stranding every existing entry. That
/// is what happened in 6.0.0, which moved filenames from the identifier's description to a
/// SHA-256 digest and left the earlier files unreadable, unexpirable and undeletable.
///
/// ## Shape
///
/// An entry lives at `<base>/[<subfolder>/]cache-v2/<digest>.cache`, where `<digest>` is the
/// lowercase hexadecimal SHA-256 of the item identifier's description. The file itself is a
/// `CodableResource` encoded by a default `JSONEncoder`: a JSON object with exactly the keys
/// `item` and `expiry`, where `expiry` is a number of seconds since 1 January 2001.
///
/// ## Ownership
///
/// Both the folder component and the file extension are chosen by this package rather than by
/// the consumer, so a file matching both is one this package wrote. That is what allows a cache
/// to clear itself by deleting its own files, instead of deleting the directory it sits in.
///
/// ## Entries written before this layout existed
///
/// They are left where they are. Nothing outside ``versionFolderName`` is ever deleted, including
/// the entries that versions up to and including 6.0.0 wrote directly into the consumer's own
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
enum FileSystemLayout {

    /// The folder, below any consumer-supplied subfolder, that holds the current layout.
    ///
    /// Change this whenever filename derivation or the record format changes, so that entries
    /// written by the previous version stay recognisable instead of becoming invisible.
    static let versionFolderName = "cache-v2"

    /// The extension carried by every entry file in the current layout.
    static let entryFileExtension = "cache"

    /// Creates a decoder that reads the record format described above.
    ///
    /// Entries are written by `Files`, which encodes with a default `JSONEncoder`, so reading one
    /// back takes a default `JSONDecoder`. The pairing is stated here, beside the description of
    /// the format, so that whoever changes one is looking at the other.
    ///
    /// - Returns: A decoder for an entry's payload.
    static func makeEntryDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    /// The path, relative to the base directory, that the current layout occupies.
    ///
    /// - Parameter subfolder: The consumer-supplied subfolder, if any.
    /// - Returns: A subfolder path to hand to a file system store.
    static func versionedSubfolder(below subfolder: String?) -> String {
        guard let subfolder, subfolder.isEmpty == false else {
            return versionFolderName
        }
        return subfolder + "/" + versionFolderName
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
}
