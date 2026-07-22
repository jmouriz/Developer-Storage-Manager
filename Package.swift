// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "XcodeStorageManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "XcodeStorageManager", targets: ["XcodeStorageManager"])
    ],
    targets: [
        .executableTarget(
            name: "XcodeStorageManager",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "XcodeStorageManagerTests",
            dependencies: ["XcodeStorageManager"]
        )
    ]
)
