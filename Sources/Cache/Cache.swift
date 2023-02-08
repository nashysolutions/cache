import Foundation

public struct Cache<Item: Identifiable> {
    
    private let database: Database<Item>
    
    /// Instantiates an instance of this value.
    /// - Parameter maxSize: The maximum record count of the database. Once
    /// this count is reached, the store is reset.
    public init(maxSize count: Int = 100) {
        database = Database<Item>(recordCountMaximum: count)
    }
    
    /// Stashes an item with the specified duration.
    ///
    /// If you want to update the expiry of a stashed
    /// item, remove it from the stash first.
    ///
    /// - Parameters:
    ///   - item: The item to stash.
    ///   - duration: The duration to stash it for.
    public func stash(_ item: Item, duration: Expiry) {
        let resource = Resource<Item>(item: item, expiry: duration.date)
        database.stash(resource)
    }
    
    public func removeResource(for identifier: Item.ID) {
        database.removeResource(for: identifier)
    }
    
    public func resource(for identifier: Item.ID) -> Item? {
        database.resource(for: identifier)?.item
    }
    
    /// Clear the cache completely.
    public func reset() {
        database.removeAll()
    }
}
