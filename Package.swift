// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "cache",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
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
