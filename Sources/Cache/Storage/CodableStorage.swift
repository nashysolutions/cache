//
//  CodableStorage.swift
//  cache
//
//  Created by Robert Nash on 15/06/2025.
//

import Foundation

/// A marker protocol for storages that support `Codable` item and resource types.
///
/// `CodableStorage` refines ``Storage`` by requiring both the stored `Item` and `Resource`
/// to conform to `Codable`, enabling archiving and transport.
///
/// This is typically used for file system or network-backed storage where serialisation is required.
protocol CodableStorage: Storage where Item: Codable, Resource: Codable {}
