// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "YMCache",
    platforms: [
        .iOS(.v9),
        .macOS(.v10_10),
        .tvOS(.v11),
        .watchOS(.v3)
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
    ]
)
