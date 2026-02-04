// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClawLaw",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "clawlaw", targets: ["ClawLawCLI"]),
        .library(name: "ClawLawCore", targets: ["ClawLawCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClawLawCLI",
            dependencies: [
                "ClawLawCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .target(
            name: "ClawLawCore",
            dependencies: []),
        .testTarget(
            name: "ClawLawTests",
            dependencies: ["ClawLawCore"]),
    ]
)
