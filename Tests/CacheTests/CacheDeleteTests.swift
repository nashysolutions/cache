import XCTest
import Foundation
@testable import Cache

final class CacheDeleteTests: XCTestCase {
    
    private let cache = Cache<Int>()
    
    func testRemove() {
        
        // given
        let identifier = UUID()
        
        // when
        let item: Int = 123
        cache.stash(item, with: identifier, duration: .short)
        cache.removeResource(for: identifier)
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testReset() {
        
        // given
        let identifier1 = UUID()
        let identifier2 = UUID()
        let item1: Int = 123
        let item2: Int = 456
        cache.stash(item1, with: identifier1, duration: .short)
        cache.stash(item2, with: identifier2, duration: .short)
        
        // when
        cache.reset()
        
        // then
        let resource1 = cache.resource(for: identifier1)
        let resource2 = cache.resource(for: identifier2)
        XCTAssertNil(resource1)
        XCTAssertNil(resource2)
    }
    
    func testResourceFetchNonExisting() {
        
        // given
        let identifier = UUID()
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
    
    func testExpiry() {
        
        // given
        let identifier = UUID()
        
        // when
        let date = Date().addingTimeInterval(1)
        let item: Int = 123
        cache.stash(item, with: identifier, duration: .custom(date))
        sleep(2)
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
}
