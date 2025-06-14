import XCTest
import Foundation
@testable import Cache

final class CacheDeleteTests: XCTestCase {
    
    private let cache = VolatileCache<TestValue>()
    
    func testRemove() async throws {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // when
        try await cache.stash(item, duration: .short)
        try await cache.removeResource(for: identifier)
        
        // then
        let resource = try await cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testReset() async throws {
        
        // given
        let item1 = TestValue(count: 123)
        let item2 = TestValue(count: 456)
        try await cache.stash(item1, duration: .short)
        try await cache.stash(item2, duration: .short)
        
        // when
        try await cache.reset()
        
        // then
        let resource1 = try await cache.resource(for: item1.id)
        let resource2 = try await cache.resource(for: item2.id)
        XCTAssertNil(resource1)
        XCTAssertNil(resource2)
    }
    
    func testResourceFetchNonExisting() async throws {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // then
        let resource = try await cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testExpiry() async throws {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // when
        let date = Date().addingTimeInterval(1)
        try await cache.stash(item, duration: .custom(date))
        sleep(2)
        
        // then
        let resource = try await cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
}
