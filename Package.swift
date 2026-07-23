// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DeveloperStorageManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "DeveloperStorageManager", targets: ["DeveloperStorageManager"])
    ],
    targets: [
        .executableTarget(
            name: "DeveloperStorageManager",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DeveloperStorageManagerTests",
            dependencies: ["DeveloperStorageManager"]
        )
    ]
)
