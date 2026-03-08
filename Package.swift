// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarpdmTerminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CarpdmCore", targets: ["CarpdmCore"]),
        .library(name: "CarpdmInfrastructure", targets: ["CarpdmInfrastructure"]),
        .library(name: "CarpdmFeatures", targets: ["CarpdmFeatures"]),
        .executable(name: "CarpdmTerminalApp", targets: ["CarpdmTerminalApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.11.2"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "6.2.3"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.0")
    ],
    targets: [
        .target(
            name: "CarpdmCore",
            path: "Sources/Core"
        ),
        .target(
            name: "CarpdmInfrastructure",
            dependencies: [
                "CarpdmCore",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Infrastructure"
        ),
        .target(
            name: "CarpdmFeatures",
            dependencies: [
                "CarpdmCore",
                "CarpdmInfrastructure"
            ],
            path: "Sources/Features"
        ),
        .executableTarget(
            name: "CarpdmTerminalApp",
            dependencies: [
                "CarpdmCore",
                "CarpdmInfrastructure",
                "CarpdmFeatures",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/App"
        ),
        .testTarget(
            name: "CarpdmUnitTests",
            dependencies: [
                "CarpdmCore",
                "CarpdmInfrastructure",
                "CarpdmFeatures",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/Unit"
        ),
        .testTarget(
            name: "CarpdmIntegrationTests",
            dependencies: [
                "CarpdmCore",
                "CarpdmInfrastructure",
                "CarpdmFeatures",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/Integration"
        )
    ]
)
