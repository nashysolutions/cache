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
}
