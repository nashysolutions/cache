import XCTest
import Foundation
@testable import Cache

final class CacheStringTests: XCTestCase {
    
    private let cache = Cache<String>()
    private let item = "Item"
    
    func testResourceFetchExisting() {
        
        // given
        let identifier = UUID()
        
        // when
        cache.stash(item, with: identifier, duration: .short)
                
        // then
        let resource = cache.resource(for: identifier)
        XCTAssertEqual(resource, item)
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
