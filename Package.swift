// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "YMCache",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "YMCache",
            targets: ["YMCache"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "YMCache",
            path: "YMCache",
            exclude: ["Info.plist"],
            publicHeadersPath: "."),
        .testTarget(
            name: "YMCacheTests",
            dependencies: ["YMCache"],
            path: "YMCacheTests",
            exclude: [
                "Info.plist", 
                "Tests-Prefix.pch",
                "YMCachePersistenceControllerSpec.m", // TODO: Un-specta-ify
                "YMMemoryCacheSpec.m" // TODO: Un-specta-ify
            ]),
    ]
)
