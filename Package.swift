// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "RuntimeLocalization",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "RuntimeLocalization",
            targets: ["RuntimeLocalization"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "RuntimeLocalization",
            dependencies: []),
        .testTarget(
            name: "RuntimeLocalizationTests",
            dependencies: ["RuntimeLocalization"]),
    ]
)
