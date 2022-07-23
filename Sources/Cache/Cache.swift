import Foundation

public struct Cache<Item> {
    
    private let database: Database<Item>
    
    public init() {
        database = Database<Item>()
    }

    public func stash(_ item: Item, with identifier: UUID, duration: Expiry) {
        let resource = Resource<Item>(item: item, identifier: identifier, expiry: duration.date)
        database.stash(resource)
    }
    
    public func removeResource(for identifier: UUID) {
        database.removeResource(for: identifier)
    }
    
    public func resource(for identifier: UUID) -> Item? {
        database.resource(for: identifier)?.item
    }
    
    /// Clear the cache completely.
    public func reset() {
        database.removeAll()
    }
}
