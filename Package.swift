// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "cache",
    platforms: [.iOS(.v16), .macOS(.v10_15)],
    products: [
        .library(
            name: "Cache",
            targets: ["Cache"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nashysolutions/foundation-dependencies.git", .upToNextMinor(from: "3.2.0"))
    ],
    targets: [
        .target(
            name: "Cache",
            dependencies: [
                .product(name: "FoundationDependencies", package: "foundation-dependencies")
            ]
        ),
        .testTarget(
            name: "CacheTests",
            dependencies: ["Cache"]
        )
    ]
)
