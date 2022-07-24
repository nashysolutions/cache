import Foundation

final class Database<Item> {
    
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
    
    func resource(for identifier: UUID) -> ResourceItem? {
        
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
    
    func removeResource(for identifier: UUID) {
        if let resource = resource(for: identifier) {
            storage.remove(resource)
        }
    }
    
    func removeAll() {
        storage.removeAll()
    }
}
