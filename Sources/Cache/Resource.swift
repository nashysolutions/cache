import Foundation

struct Resource<Item: Identifiable>: Hashable {
    
    let item: Item
    let expiry: Date
    
    var identifier: Item.ID {
        item.id
    }
            
    var isExpired: Bool {
        expiry < Date()
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
