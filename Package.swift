// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MiniPulse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MiniPulse", targets: ["MiniPulse"])
    ],
    targets: [
        .executableTarget(
            name: "MiniPulse",
            path: "Sources/MiniPulse"
        ),
        .testTarget(
            name: "MiniPulseTests",
            dependencies: ["MiniPulse"],
            path: "Tests/MiniPulseTests"
        )
    ]
)
