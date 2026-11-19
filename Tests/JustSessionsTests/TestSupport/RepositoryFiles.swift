import Foundation

enum RepositoryFiles {
    static let rootDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func contents(of relativePath: String) throws -> String {
        try String(contentsOf: rootDirectory.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
