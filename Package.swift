// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FnX",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FnX",
            path: "Sources/FnX",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Cocoa"),
                .linkedFramework("Security"),
            ]
        )
    ]
)
