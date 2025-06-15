//
//  AnyResourceBox.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

struct AnyResourceBox {
    
    private let _value: Any
    private let _type: Any.Type
    
    init<T>(_ value: T) {
        self._value = value
        self._type = T.self
    }
    
    func cast<T>(to _: T.Type) throws -> T {
        guard let typed = _value as? T else {
            throw NSError(domain: "type-mismatch", code: 0, userInfo: [
                "expected": String(describing: T.self),
                "actual": String(describing: _type)
            ])
        }
        return typed
    }
}
