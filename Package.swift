// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "cache",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Cache",
            targets: ["Cache"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nashysolutions/foundation-dependencies.git", .upToNextMinor(from: "5.0.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMinor(from: "1.8.1"))
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
            dependencies: [
                "Cache",
                    .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ]
        )
    ]
)
