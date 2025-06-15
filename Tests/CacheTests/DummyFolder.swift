//
//  DummyFolder.swift
//  cache
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Files

struct DummyFolder: Directory {
    let location = URL(fileURLWithPath: "/dev/null")
}
