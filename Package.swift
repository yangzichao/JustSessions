// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JustSessions",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "JustSessions", targets: ["JustSessions"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.10.0"),
        // SwiftTerm 1.15.0 plus `minimumContrastRatio`; see docs/development/build-and-release.md#swiftterm-fork.
        .package(url: "https://github.com/yangzichao/SwiftTerm.git", exact: "1.15.0-justsessions.1"),
        .package(url: "https://github.com/cucumberswift/CucumberSwift.git", exact: "6.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "JustSessions",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            resources: [.process("Resources/Localization"), .copy("Resources/ReleaseNotes"), .copy("Resources/Fonts")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "JustSessionsTests",
            dependencies: [
                "JustSessions",
                .product(name: "CucumberSwift", package: "CucumberSwift"),
            ],
            // CucumberSwift reads the Gherkin features from a resource folder that must be named Features.
            resources: [.copy("Gherkin/Features")]
        ),
    ]
)
