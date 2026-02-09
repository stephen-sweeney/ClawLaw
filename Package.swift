// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClawLaw",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
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
    ],
    targets: [
        // The core governance library
        .target(
            name: "ClawLawCore",
            dependencies: []
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
            dependencies: ["ClawLawCore"]
        ),
    ]
)
