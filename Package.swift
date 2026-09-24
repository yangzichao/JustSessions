// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CocaCodex",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CocaCodex", targets: ["CocaCodex"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "CocaCodex",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(name: "CocaCodexTests", dependencies: ["CocaCodex"]),
    ]
)
