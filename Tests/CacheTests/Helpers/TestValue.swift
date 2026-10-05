//
//  TestValue.swift
//  
//
//  Created by Robert Nash on 08/02/2023.
//

import Foundation

/// An item whose identifier is its only field.
///
/// It is `Equatable` so that a test can assert which item a cache served, not merely that it
/// served one: a cache that answered with the wrong item would pass a presence check.
struct TestValue: Identifiable, Equatable, Sendable {

    let count: String

    var id: String { count }
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

/// An item whose content can change while its identifier stays the same, for the tests that pin
/// what a second stash under one identifier does.
///
/// None of the types above can express that. Each derives its identifier from its only field, so
/// two different values of one of them never share an identifier, and stashing "the same
/// identifier twice" with them only ever stashes the same value twice. It is `Codable` so that one
/// type serves both caches.
struct TestDocument: Identifiable, Equatable, Codable, Sendable {

    let id: String

    let body: String
}
