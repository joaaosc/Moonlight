// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoonlightKit",
    platforms: [
        .macOS("27.0"),
    ],
    products: [
        .library(name: "MoonlightDomain", targets: ["MoonlightDomain"]),
        .library(name: "MoonlightInfrastructure", targets: ["MoonlightInfrastructure"]),
        .library(name: "MoonlightSnippetUI", targets: ["MoonlightSnippetUI"]),
        .library(name: "MoonlightIntents", targets: ["MoonlightIntents"]),
        .library(name: "MoonlightAppUI", targets: ["MoonlightAppUI"]),
        .library(name: "MoonlightShortcuts", targets: ["MoonlightShortcuts"]),
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
                // For the entity identifiers the UI annotates onscreen content
                // with. MoonlightIntents does not depend on the UI, so this
                // does not create a cycle.
                "MoonlightIntents",
            ]
        ),
        // Apple Events live in their own target: the App Intents extension
        // links MoonlightKit and must not gain a scripting dependency.
        .target(
            name: "MoonlightShortcuts",
            dependencies: ["MoonlightDomain"]
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
            name: "MoonlightShortcutsTests",
            dependencies: [
                "MoonlightDomain",
                "MoonlightShortcuts",
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
