// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TranslateTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TranslateTool", targets: ["TranslateTool"])
    ],
    targets: [
        .executableTarget(
            name: "TranslateTool",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
