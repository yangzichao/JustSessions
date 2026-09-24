// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationManager",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ConversationManager", targets: ["ConversationManager"])],
    targets: [
        .executableTarget(name: "ConversationManager"),
        .testTarget(name: "ConversationManagerTests", dependencies: ["ConversationManager"]),
    ]
)
