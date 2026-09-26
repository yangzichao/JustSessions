import Foundation

/// Files of this repository, for tests that check the app's code against its build script and package manifest.
enum RepositoryFiles {
    /// This file is `Tests/JustSessionsTests/TestSupport/RepositoryFiles.swift`.
    static let rootDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func contents(of relativePath: String) throws -> String {
        try String(contentsOf: rootDirectory.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
