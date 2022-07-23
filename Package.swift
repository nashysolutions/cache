// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cache",
    platforms: [.iOS(.v9), .macOS(.v10_10)],
    products: [
        .library(
            name: "Cache",
            targets: ["Cache"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Cache",
            dependencies: []),
        .testTarget(
            name: "CacheTests",
            dependencies: ["Cache"]
        )
    ]
)
