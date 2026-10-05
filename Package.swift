// swift-tools-version:6.0

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
            targets: ["Cache"])
    ],
    dependencies: [
        // foundation-dependencies declares the dependency key that this package supplies the live
        // value for. An upstream release that ships its own live value would stop this package
        // compiling, so the range admits one upstream minor at a time, and is widened only after the
        // next minor has been built and tested here. See #40.
        .package(url: "https://github.com/nashysolutions/foundation-dependencies.git", "6.0.0"..<"7.1.0"),
        .package(url: "https://github.com/nashysolutions/files.git", .upToNextMinor(from: "3.0.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMinor(from: "1.8.1"))
    ],
    targets: [
        .target(
            name: "Cache",
            dependencies: [
                .product(name: "FoundationDependencies", package: "foundation-dependencies"),
                .product(name: "Files", package: "files"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        // The tests import these modules themselves, so they are named here
        // rather than reached through Cache's own dependencies, which may
        // change without the tests changing.
        .testTarget(
            name: "CacheTests",
            dependencies: [
                "Cache",
                .product(name: "FoundationDependencies", package: "foundation-dependencies"),
                .product(name: "Files", package: "files"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ]
        )
    ]
)
