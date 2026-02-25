// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClawLaw",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // The ClawLaw CLI executable
        .executable(
            name: "clawlaw",
            targets: ["ClawLaw"]
        ),
        // The core library for embedding in other projects
        .library(
            name: "ClawLawCore",
            targets: ["ClawLawCore"]
        ),
    ],
    dependencies: [
        // ArgumentParser for CLI
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        // SwiftVector governance framework
        .package(path: "../SwiftVector"),
    ],
    targets: [
        // The core governance library
        .target(
            name: "ClawLawCore",
            dependencies: [
                .product(name: "SwiftVectorCore", package: "SwiftVector"),
            ]
        ),

        // The CLI executable
        .executableTarget(
            name: "ClawLaw",
            dependencies: [
                "ClawLawCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // Tests
        .testTarget(
            name: "ClawLawTests",
            dependencies: [
                "ClawLawCore",
                .product(name: "SwiftVectorCore", package: "SwiftVector"),
                .product(name: "SwiftVectorTesting", package: "SwiftVector"),
            ]
        ),
    ]
)
