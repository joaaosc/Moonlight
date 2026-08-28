// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoonlightKit",
    platforms: [
        .macOS(.v27),
    ],
    products: [
        .library(name: "MoonlightDomain", targets: ["MoonlightDomain"]),
        .library(name: "MoonlightInfrastructure", targets: ["MoonlightInfrastructure"]),
        .library(name: "MoonlightSnippetUI", targets: ["MoonlightSnippetUI"]),
        .library(name: "MoonlightIntents", targets: ["MoonlightIntents"]),
        .library(name: "MoonlightAppUI", targets: ["MoonlightAppUI"]),
    ],
    targets: [
        .target(name: "MoonlightDomain"),
        .target(
            name: "MoonlightInfrastructure",
            dependencies: ["MoonlightDomain"]
        ),
        .target(
            name: "MoonlightSnippetUI",
            dependencies: ["MoonlightDomain"]
        ),
        .target(
            name: "MoonlightIntents",
            dependencies: [
                "MoonlightDomain",
                "MoonlightInfrastructure",
                "MoonlightSnippetUI",
            ]
        ),
        .target(
            name: "MoonlightAppUI",
            dependencies: [
                "MoonlightDomain",
                "MoonlightInfrastructure",
            ]
        ),
        .testTarget(
            name: "MoonlightDomainTests",
            dependencies: ["MoonlightDomain"]
        ),
        .testTarget(
            name: "MoonlightInfrastructureTests",
            dependencies: [
                "MoonlightDomain",
                "MoonlightInfrastructure",
            ]
        ),
        .testTarget(
            name: "MoonlightIntentsTests",
            dependencies: [
                "MoonlightDomain",
                "MoonlightInfrastructure",
                "MoonlightIntents",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
