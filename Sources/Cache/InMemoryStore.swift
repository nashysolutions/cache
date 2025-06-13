import Foundation

final class InMemoryStore<Item: Identifiable>: ResourceProvider {
    
    typealias ResourceItem = Resource<Item>
    
    private var storage = Set<ResourceItem>()
    
    let recordCountMaximum: Int
    
    init(recordCountMaximum: Int) {
        self.recordCountMaximum = recordCountMaximum
    }
    
    func stash(_ resource: ResourceItem) {
        clearStorageIfNecessary()
        storage.insert(resource)
    }
    
    private func clearStorageIfNecessary() {
        if storage.count >= recordCountMaximum {
            removeAll()
        }
    }
    
    func resource(for identifier: Item.ID) -> ResourceItem? {
        
        let predicate: (ResourceItem) -> Bool = {
            $0.identifier == identifier
        }
                
        guard let resource = storage.first(where: predicate) else {
            return nil
        }
        
        guard !resource.isExpired else {
            storage.remove(resource)
            return nil
        }
        
        return resource
    }
    
    func removeResource(for identifier: Item.ID) {
        if let resource = resource(for: identifier) {
            storage.remove(resource)
        }
    }
    
    func removeAll() {
        storage.removeAll()
    }
}
