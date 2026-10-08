//
//  CacheDirectory.swift
//  cache
//
//  Created by Robert Nash on 08/10/2026.
//

import Foundation
import Files

/// One of the well-known app directories a ``FileSystemCache`` can write below.
///
/// This is the type a ``FileSystemCache`` is constructed with, and it is declared in this package
/// so that constructing a cache needs nothing but `import Cache`. Each case names the same
/// directory as the `Files` package's case of the same name, which is what the cache resolves it
/// through.
///
/// The directories differ in whether backups include them and whether the system may delete their
/// contents, so choose by what losing an entry would cost. What each case says about backups and
/// deletion is iOS's behaviour.
public enum CacheDirectory: Sendable, CaseIterable {

    /// The app's Documents directory.
    ///
    /// Backups include it, and the system never deletes its contents. The user can see it when the
    /// app opts into file sharing.
    ///
    /// - Important: On a non-sandboxed macOS process, this is the user's real `~/Documents`.
    case documents

    /// The app's Caches directory.
    ///
    /// Backups exclude it, and the system may delete its contents when the device is low on
    /// storage, so use it for entries that can be fetched again.
    case caches

    /// The app's Application Support directory.
    ///
    /// Backups include it, the system never deletes its contents, and the user does not see it. It
    /// is created on first use, because a fresh app container does not have one.
    case applicationSupport

    /// The temporary directory.
    ///
    /// Backups exclude it, and the system may delete its contents whenever the app is not running.
    case temporary
}

extension CacheDirectory {

    /// The `Files` directory this case resolves through.
    ///
    /// Every case maps to the `Files` case of the same name, so a cache built with a
    /// `CacheDirectory` reads and writes where one built with the matching `FileSystemDirectory`
    /// did. The switch has no default, so a case added here does not compile until it is mapped.
    var fileSystemDirectory: FileSystemDirectory {
        switch self {
        case .documents: .documents
        case .caches: .caches
        case .applicationSupport: .applicationSupport
        case .temporary: .temporary
        }
    }
}
