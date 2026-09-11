//
//  TestValue.swift
//  
//
//  Created by Robert Nash on 08/02/2023.
//

import Foundation

struct TestValue: Identifiable, LosslessStringConvertible, Sendable {

    let count: String

    var id: String { count }

    var description: String { count }

    init(count: String) {
        self.count = count
    }

    init?(_ description: String) {
        guard !description.isEmpty else { return nil }
        self.count = description
    }
}

struct CodableTestValue: Identifiable, Codable {

    var id: String {
        count
    }

    let count: String
}

/// A second item type, for the tests that put two caches in one directory.
///
/// Its stored shape shares no property name with ``CodableTestValue``, so neither can decode the
/// other's payload. That is what makes a cross-type collision destructive rather than merely
/// confusing: an entry that does not decode is deleted, so before entries were scoped by item
/// type, each cache cleared the other's data on the first read.
struct OtherCodableTestValue: Identifiable, Codable {

    var id: String {
        label
    }

    let label: String
}
