import Foundation

struct Resource<Item>: Hashable {
    
    let item: Item
    let identifier: UUID
    let expiry: Date
            
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
