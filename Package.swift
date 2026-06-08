// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VibePlayer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VibePlayerCore", targets: ["VibePlayerCore"]),
        .executable(name: "VibePlayer", targets: ["VibePlayer"])
    ],
    targets: [
        .target(
            name: "VibePlayerCore",
            path: "Sources/VibePlayerCore"
        ),
        .executableTarget(
            name: "VibePlayer",
            dependencies: ["VibePlayerCore"],
            path: "Sources/VibePlayer"
        ),
        .testTarget(
            name: "VibePlayerTests",
            dependencies: ["VibePlayerCore"],
            path: "Tests/VibePlayerTests"
        )
    ]
)
