// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FnX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FnXUI",
            targets: ["FnXUI"]
        ),
        .executable(
            name: "FnX",
            targets: ["FnX"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "FnXUI",
            dependencies: ["SwiftWhisper"],
            path: "Sources/FnX",
            exclude: ["App"],
            resources: [
                .copy("Resources/ggml-base.bin")
            ]
        ),
        .executableTarget(
            name: "FnX",
            dependencies: ["FnXUI"],
            path: "Sources/FnX/App",
            exclude: ["Untitled"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Cocoa"),
                .linkedFramework("Security"),
            ]
        )
    ]
)
