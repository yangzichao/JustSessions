import Foundation

enum RepositoryFiles {
    private static let thisFilesPathInRepository = "Tests/JustSessionsTests/TestSupport/RepositoryFiles.swift"

    static let rootDirectory: URL = {
        let pathComponentsBelowRoot = thisFilesPathInRepository.split(separator: "/").count
        return (0..<pathComponentsBelowRoot).reduce(URL(fileURLWithPath: #filePath)) { directory, _ in
            directory.deletingLastPathComponent()
        }
    }()

    static func contents(of relativePath: String) throws -> String {
        try String(contentsOf: rootDirectory.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
