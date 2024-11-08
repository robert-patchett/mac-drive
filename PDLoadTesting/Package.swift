// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDLoadTesting",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "PDLoadTesting",
            targets: ["PDLoadTesting"]
        ),
    ],
    targets: [
        .target(
            name: "PDLoadTesting"
        )
    ]
)
