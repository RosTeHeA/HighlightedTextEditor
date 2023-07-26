// swift-tools-version:5.3

import PackageDescription

public let package = Package(
    name: "HighlightedTextEditor",
    platforms: [
        .macOS(.v11),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "HighlightedTextEditor",
            targets: ["HighlightedTextEditor"]
        )
    ],
    targets: [
        .target(
            name: "HighlightedTextEditor",
            dependencies: []
        )
    ]
)
