// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudexMacOS",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClaudexMacOS", targets: ["ClaudexMacOS"])],
    targets: [
        .executableTarget(name: "ClaudexMacOS"),
        .testTarget(name: "ClaudexMacOSTests", dependencies: ["ClaudexMacOS"]),
    ]
)
