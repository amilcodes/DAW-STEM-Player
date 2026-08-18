// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "StemPlayer",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StemPlayer", targets: ["StemPlayer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "StemPlayer",
            path: "Sources/StemPlayer",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Accelerate"),
                .linkedFramework("AppKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "StemPlayerTests",
            dependencies: ["StemPlayer"],
            path: "Tests/StemPlayerTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
