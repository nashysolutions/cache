import XCTest
import Foundation

@testable import Cache

final class CacheMaxCountTests: XCTestCase {
    
    func testResourceMaxSizeExceeded() async throws {
        
        // given - a max size of 2 entries
        let cache = VolatileCache<TestValue>(maxSize: 2)
        
        let item1 = TestValue(count: 123)
        let item2 = TestValue(count: 456)
        let item3 = TestValue(count: 789)
        let identifier1 = item1.id
        let identifier2 = item2.id
        let identifier3 = item3.id
        
        // and - we reach the max size
        try await cache.stash(item1, duration: .short)
        try await cache.stash(item2, duration: .short)
        
        // when - we exceed the cache limit
        try await cache.stash(item3, duration: .short)
                
        // then - the database is purged of all previous entries
        let resource1 = try await cache.resource(for: identifier1)
        let resource2 = try await cache.resource(for: identifier2)
        XCTAssertNil(resource1)
        XCTAssertNil(resource2)
        
        // and - the latest entry is successfully stored
        let resource3 = try await cache.resource(for: identifier3)
        XCTAssertNotNil(resource3)
    }
}
