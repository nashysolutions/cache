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
    
    /// Verifies that `FileSystemResourceClient.makeStore` is called with the expected
    /// directory and subfolder arguments.
    ///
    /// This test also confirms that the `makeStore` closure is executed exactly once.
    @Test("The makeStore closure captures the correct directory and subfolder")
    func testMakeStoreReceivesCorrectFolderArguments() async throws {
        
        try await confirmation(
            "Expected makeStore to be called exactly once with `.temporary` and 'test-folder'",
            expectedCount: 1
        ) { confirmation in
            
            let client = FileSystemResourceClient(
                makeStore: { directory, subfolder in
                    defer { confirmation() }
                    let folderStore = MockFileSystemFolderStore()
                    #expect(directory == .temporary)
                    #expect(subfolder == "test-folder")
                    return folderStore
                }
            )
            
            _ = try client.makeStore(.temporary, "test-folder")
        }
    }
    
    /// Tests that removing a resource:
    /// 1. Loads the resource (to ensure it exists)
    /// 2. Deletes it via the store
    @Test("Removing a resource loads and deletes the file")
    func testRemoveResourceCallsLoadAndDelete() async throws {
        
        // Given: a mock store that simulates a successful load for filenames like "5"
        let folderStore = MockFileSystemFolderStore()
        folderStore.loadHandler = { filename in
            guard let count = Int(filename) else {
                throw NSError(domain: "invalid-filename", code: 0, userInfo: ["filename": filename])
            }
            let item = CodableTestValue(count: count)
            let resource = CodableResource(item: item, expiry: .now)
            return AnyResourceBox(resource)
        }
        
        // Create a nonisolated copy to avoid capturing a non-Sendable reference in a @Sendable closure
        nonisolated(unsafe) let store = folderStore
        let cache: FileSystemCache<CodableTestValue> = withDependencies {
            $0.fileSystemResourceClient = .init(
                makeStore: { _, _ in store }
            )
        } operation: {
            .init(.temporary, subfolder: "test-folder")
        }
        
        // When: removing a resource with ID 5
        try await cache.removeResource(for: 5)
        
        // Then: loadResource and deleteResource should both have been called
        #expect(folderStore.called == [
            .loadResource,     // ✅ load endpoint hit (mocked success so moves on to delete)
            .deleteResource    // ✅ delete endpoint hit
        ])
    }
}

