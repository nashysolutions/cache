import XCTest
import Foundation
@testable import Cache

final class CacheMaxCountTests: XCTestCase {
    
    func testResourceMaxSizeExceeded() {
        
        // given - a max size of 2 entries
        let cache = Cache<Int>(maxSize: 2)
        
        let identifier1 = UUID()
        let identifier2 = UUID()
        let identifier3 = UUID()
        let item1: Int = 123
        let item2: Int = 456
        let item3: Int = 789
        
        // and - we reach the max size
        cache.stash(item1, with: identifier1, duration: .short)
        cache.stash(item2, with: identifier2, duration: .short)
        
        // when - we exceed the cache limit
        cache.stash(item3, with: identifier3, duration: .short)
                
        // then - the database is purged of all previous entries
        let resource1 = cache.resource(for: identifier1)
        let resource2 = cache.resource(for: identifier2)
        XCTAssertNil(resource1)
        XCTAssertNil(resource2)
        
        // and - the latest entry is successfully stored
        let resource3 = cache.resource(for: identifier3)
        XCTAssertNotNil(resource3)
    }
}
