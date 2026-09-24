// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudexMacOS",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClaudexMacOS", targets: ["ClaudexMacOS"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudexMacOS",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        .testTarget(name: "ClaudexMacOSTests", dependencies: ["ClaudexMacOS"]),
    ]
)
