// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FluentApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FluentCore", targets: ["FluentCore"]),
        .executable(name: "FluentApp", targets: ["FluentApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "FluentCore",
            dependencies: []
        ),
        .target(
            name: "FluentMacSupport",
            dependencies: ["FluentCore"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "FluentApp",
            dependencies: [
                "FluentCore",
                "FluentMacSupport",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/FluentApp",
            exclude: [
                "Contracts",
                "Model",
                "Providers",
                "Services"
            ],
            sources: [
                "FluentApp.swift",
                "UI/SettingsView.swift",
                "UI/ShortcutEditView.swift",
                "UI/ShortcutRecorderView.swift",
                "UI/AIProviderSettingsView.swift"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "FluentAppTests",
            dependencies: ["FluentCore"],
            path: "Tests/FluentAppTests"
        )
    ]
)
