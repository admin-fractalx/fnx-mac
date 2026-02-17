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
    dependencies: [],
    targets: [
        .target(
            name: "FnXUI",
            dependencies: [],
            path: "Sources/FnX",
            exclude: ["App"],
            resources: [
                .copy("Resources/AppLogo.png"),
                .copy("Resources/menubar_icon.png"),
                .copy("Resources/menubar_icon@2x.png"),
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
