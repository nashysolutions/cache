import XCTest
import Foundation
@testable import Cache

final class CacheDeleteTests: XCTestCase {
    
    private let cache = Cache<TestValue>()
    
    func testRemove() async {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // when
        await cache.stash(item, duration: .short)
        await cache.removeResource(for: identifier)
        
        // then
        let resource = await cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testReset() async {
        
        // given
        let item1 = TestValue(count: 123)
        let item2 = TestValue(count: 456)
        await cache.stash(item1, duration: .short)
        await cache.stash(item2, duration: .short)
        
        // when
        await cache.reset()
        
        // then
        let resource1 = await cache.resource(for: item1.id)
        let resource2 = await cache.resource(for: item2.id)
        XCTAssertNil(resource1)
        XCTAssertNil(resource2)
    }
    
    func testResourceFetchNonExisting() async {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // then
        let resource = await cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testExpiry() async {
        
        // given
        let item = TestValue(count: 123)
        let identifier = item.id
        
        // when
        let date = Date().addingTimeInterval(1)
        await cache.stash(item, duration: .custom(date))
        sleep(2)
        
        // then
        let resource = await cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
}
