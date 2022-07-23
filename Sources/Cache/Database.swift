import Foundation

final class Database<Item> {
    
    typealias ResourceItem = Resource<Item>
    
    private var storage = Set<ResourceItem>()
    
    func stash(_ resource: ResourceItem) {
        storage.insert(resource)
    }
    
    func resource(for identifier: UUID) -> ResourceItem? {
        let predicate: (ResourceItem) -> Bool = {
            $0.identifier == identifier
        }
        guard let resource = storage.first(where: predicate) else {
            return nil
        }
        if resource.isExpired {
            storage.remove(resource)
            return nil
        }
        return resource
    }
}
