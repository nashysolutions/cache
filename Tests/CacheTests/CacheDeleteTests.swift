import XCTest
import Foundation
@testable import Cache

final class CacheDeleteTests: XCTestCase {
    
    private let cache = Cache<Int>()
    private let item: Int = 123
    
    func testRemove() {
        
        // given
        let identifier = UUID()
        
        // when
        cache.stash(item, with: identifier, duration: .short)
        cache.removeResource(for: identifier)
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
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
        cache.stash(item, with: identifier, duration: .custom(date))
        sleep(2)
        
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertNil(resource)
    }
}
