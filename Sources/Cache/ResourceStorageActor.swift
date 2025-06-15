//
//  ResourceStorageActor.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation

/// A global actor used to isolate access to resource storage operations.
///
/// `ResourceStorageActor` ensures that all interactions with resource-backed storage
/// (such as inserting, removing, or querying cached items) are performed in a serial,
/// thread-safe manner.
///
/// Use this actor to coordinate access to types that manage in-memory or shared resource state,
/// especially in contexts like caching or database-like abstractions.
@globalActor
actor ResourceStorageActor: GlobalActor {
    
    /// The shared instance of the global actor.
    static let shared = ResourceStorageActor()
}
