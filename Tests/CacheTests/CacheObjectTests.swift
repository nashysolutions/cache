import XCTest
import Foundation
@testable import Cache

final class CacheObjectTests: XCTestCase {
    
    private let cache = Cache<NSString>()
    private let item: NSString = "Item"
    
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
