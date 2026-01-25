// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FluentApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FluentApp", targets: ["FluentApp"])
    ],
    targets: [
        .executableTarget(
            name: "FluentApp",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "FluentAppTests",
            dependencies: [],
            path: "Tests/FluentAppTests"
        )
    ]
)
