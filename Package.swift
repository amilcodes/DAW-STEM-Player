// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "StemPlayer",
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
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "StemPlayerTests",
            dependencies: ["StemPlayer"],
            path: "Tests/StemPlayerTests"
        )
    ]
)
