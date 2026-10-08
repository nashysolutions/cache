//
//  FileSystemContainment.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Foundation

/// The rule that keeps the folder ``FileSystemStorage`` uses inside the base directory.
///
/// A consumer-supplied subfolder is joined to the base directory as written, by `Files` and by
/// ``FileSystemLayout``, and nothing in either join stops a path from leaving it: `"../x"` lands
/// beside the base directory, and a symbolic link inside it lands wherever the link points. Every
/// operation therefore checks the folder it is about to create before creating it, and refuses one
/// that resolves outside the base directory.
///
/// ## The rule
///
/// A folder is accepted when both of these hold:
///
/// 1. **The subfolder has no `..` component.** This is judged on the text alone, so it does not
///    depend on what is on disk.
/// 2. **The folder sits inside the base directory once every symbolic link in either is
///    followed.** Resolving both sides is what makes the comparison true on macOS, where the
///    temporary directory lives under `/var`, which is itself a link to `/private/var`.
///
/// Nested subfolders such as `"a/b"` are accepted, as are `""` and `"."`, which name the base
/// directory itself. A leading `/` is accepted too, because both joins treat it as a separator
/// rather than as the root, so `"/x"` lands at `<base>/x`.
///
/// ## Why `..` is refused outright
///
/// Rule 2 alone would accept `"a/../b"`, which stays inside, and it is still not enough on its
/// own. A `..` after a symbolic link means the parent of the link's *target*, so `"link/../x"`
/// lands beside wherever `link` points. Foundation's own resolution gets this wrong: measured on
/// macOS 27, `resolvingSymlinksInPath()` and `standardizedFileURL` both place `"link/../x"` at
/// `<base>/x`, while the file system creates it beside the link's target. Refusing the component
/// removes the one case where the text and the file system can disagree, and no documented use of
/// a subfolder needs it.
///
/// ## What is resolved, and what is left to the operation
///
/// The parts of the folder that already exist are resolved with `realpath(3)`. The parts that do
/// not exist yet are taken as written, which is exact once there is no `..` left in them: nothing
/// is there to follow, and the operation creates each one as a plain directory.
///
/// A symbolic link that cannot be followed, because its target is missing or it loops, is refused.
/// Where it would lead cannot be shown to be inside.
///
/// Any other failure to resolve, such as a directory that cannot be searched, is left to the
/// operation, which meets the same failure at the same place and reports the file system's own
/// error. Refusing it here would report a permissions fault as a containment fault.
///
/// ## What this does not cover
///
/// The check reads the real file system through `FileManager` and `realpath(3)`, because
/// `FileSystemContext` has no way to ask about links. For a context whose locations are not on
/// the real file system, nothing resolves and rule 2 compares the paths as written.
///
/// It is a check made before the operation, not a lock held during it. A link created inside the
/// base directory between the check and the write is not seen. Creating one needs write access to
/// that directory, which is already enough to replace anything the cache stores there.
///
/// ## An entry's own filename
///
/// The rule above covers the folder, not each entry inside it. A symbolic link at an entry's own
/// filename is handled by the operation that meets it, and none of them follows it:
///
/// - **A write replaces the link.** ``FileSystemStorage`` writes every entry atomically: the
///   bytes go to a temporary file beside the entry, which is then renamed over the entry's
///   filename. A rename replaces a link rather than following it, so nothing is written where the
///   link points. This holds with no check beforehand, so there is no window between a check and
///   the write.
/// - **A read does not serve what the link points to.** A link at an entry's filename is never an
///   entry, because this package writes only regular files there. The read path asks
///   ``isSymbolicLink(_:)`` first, and treats a link like an entry that does not decode: it reports
///   a miss and deletes the link. That is a check made before the read, so a link created between
///   the two is followed, on the same precondition as above.
/// - **A delete removes the link itself.** The live file system context deletes through
///   `FileManager`, which deletes a link, not its target.
///
/// The write is the operation that could change a file outside the base directory, and it is
/// protected without a check, so the window that the read leaves does not apply to it.
enum FileSystemContainment {

    /// Confirms that a folder below the base directory resolves inside it.
    ///
    /// - Parameters:
    ///   - folder: The path of the folder, relative to the base directory, as handed to a file
    ///     system store.
    ///   - subfolder: The consumer-supplied subfolder that `folder` begins with, if any. It is the
    ///     only part of `folder` this package did not choose, so it is the part checked for `..`.
    ///   - base: The base directory, as the file system client resolved it.
    /// - Throws: `CocoaError.fileWriteInvalidFileName`, carrying the folder's location, if the
    ///   folder resolves outside the base directory or cannot be shown to resolve inside it.
    static func verify(folder: String, subfolder: String?, below base: URL) throws {

        // The same join `Files` makes, so that what is checked is where the store will be.
        let location = base.appendingPathComponent(folder, isDirectory: true)

        guard containsParentReference(subfolder) == false,
              let resolvedLocation = resolvedComponents(of: location),
              let resolvedBase = resolvedComponents(of: base),
              resolvedLocation.starts(with: resolvedBase) else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [
                NSURLErrorKey: location,
                NSFilePathErrorKey: location.path,
                NSLocalizedFailureReasonErrorKey: "The cache folder resolves outside the base directory."
            ])
        }
    }

    /// Whether a subfolder has a `..` component.
    private static func containsParentReference(_ subfolder: String?) -> Bool {
        guard let subfolder else {
            return false
        }
        return subfolder.split(separator: "/", omittingEmptySubsequences: true).contains("..")
    }

    /// The components of a location with every symbolic link in its existing part followed.
    ///
    /// The deepest part of the location that resolves is resolved, and the rest is appended as
    /// written. Whatever stops a deeper part resolving is either an absence, or a fault the
    /// operation will meet in the same place, as the type's documentation describes.
    ///
    /// - Parameter location: A file URL. Its path must not contain `..` below the deepest part
    ///   that resolves, or the components appended as written are not where the file system
    ///   would put them.
    /// - Returns: The resolved components, or `nil` if the location passes through a symbolic link
    ///   that cannot be followed.
    private static func resolvedComponents(of location: URL) -> [String]? {

        let components = location.pathComponents.filter { $0 != "." }

        // The first component is always the root, which always resolves, so this returns from
        // inside the loop.
        for depth in stride(from: components.count, to: 0, by: -1) {

            let prefix = NSString.path(withComponents: Array(components[..<depth]))

            if let resolved = realPath(prefix) {
                return URL(fileURLWithPath: resolved).pathComponents + components[depth...]
            }

            if isSymbolicLink(prefix) {
                return nil
            }
        }

        return components
    }

    /// `realpath(3)`, which resolves every link in a path that exists, and fails for one that does
    /// not.
    ///
    /// It is used rather than `resolvingSymlinksInPath()`, which is documented to remove a leading
    /// `/private`, and on macOS 27 reports the temporary directory under `/var` where `realpath(3)`
    /// reports `/private/var`. Comparing two of its answers would depend on that removal being
    /// applied to both alike. `realpath(3)` reports the path the file system itself uses.
    private static func realPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else {
            return nil
        }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// Whether the last component of a path is a symbolic link, without following it.
    ///
    /// Like the rest of this type, it asks the real file system. For a location that is not on
    /// it, the answer is `false`.
    static func isSymbolicLink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }
}
