//
//  FileSystemCacheTests.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import FoundationDependencies
import Files

@testable import Cache

@Suite("FileSystemCacheTests")
struct FileSystemCacheTests {

    /// Tests that removing a resource deletes it without reading it first.
    ///
    /// The load is what a removal must not do: an entry whose stored payload no longer decodes
    /// would be unremovable if removal depended on reading it. The mock's load always throws, so
    /// any attempt to read through the store would fail outright rather than pass unnoticed.
    ///
    /// The delete is observed on the agent rather than on the store, because storage no longer
    /// goes through `Files`' `deleteResource`. That call wraps every failure in an error type
    /// internal to `Files`, which a consumer can neither name nor match on, so deletes now go
    /// straight to the file system context. The store recording nothing is therefore part of what
    /// is asserted here, not an omission.
    @Test("Removing a resource deletes the file without loading it")
    func testRemoveResourceDeletesWithoutLoading() async throws {

        // Given: a mock store
        let folderStore = MockFileSystemFolderStore()

        // Create a nonisolated copy to avoid capturing a non-Sendable reference in a @Sendable closure
        nonisolated(unsafe) let store = folderStore
        let cache: FileSystemCache<CodableTestValue> = withDependencies {
            $0.fileSystemResourceClient = .init(
                makeStore: { _, _ in store }
            )
        } operation: {
            FileSystemCache(.temporary, subfolder: "test-folder")
        }

        // When: removing a resource with ID 5
        try await cache.removeResource(for: "5")

        // Then: the entry is deleted, and nothing reads it, and nothing asks whether it is there
        #expect(folderStore.agent.called == [.deleteLocation])
        #expect(folderStore.called == [])
    }
}
