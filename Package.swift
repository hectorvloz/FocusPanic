// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusPanic",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FocusPanic",
            targets: ["FocusPanic"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FocusPanic",
            dependencies: [],
            path: "Sources/FocusPanic",
            resources: []
        ),
        .testTarget(
            name: "FocusPanicTests",
            dependencies: ["FocusPanic"],
            path: "Tests/FocusPanicTests"
        )
    ]
)
