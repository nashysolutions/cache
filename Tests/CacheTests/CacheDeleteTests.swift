import XCTest
import Foundation
@testable import Cache

final class CacheDeleteTests: XCTestCase {
    
    private let cache = Cache<TestValue>()
    
    func testRemove() {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // when
        cache.stash(item, duration: .short)
        cache.removeResource(for: identifier)
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testReset() {
        
        // given
        let item1 = TestValue(count: 123)
        let item2 = TestValue(count: 456)
        cache.stash(item1, duration: .short)
        cache.stash(item2, duration: .short)
        
        // when
        cache.reset()
        
        // then
        let resource1 = cache.resource(for: item1.id)
        let resource2 = cache.resource(for: item2.id)
        XCTAssertNil(resource1)
        XCTAssertNil(resource2)
    }
    
    func testResourceFetchNonExisting() {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testExpiry() {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // when
        let date = Date().addingTimeInterval(1)
        cache.stash(item, duration: .custom(date))
        sleep(2)
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
}
