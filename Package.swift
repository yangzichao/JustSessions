// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JustSessions",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "JustSessions", targets: ["JustSessions"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "JustSessions",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(name: "JustSessionsTests", dependencies: ["JustSessions"]),
    ]
)
