import Foundation

/// A new, empty folder for one test; the test removes it with `defer`.
func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JustSessionsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// Writes `script` to `file` and makes it executable, standing in for an installed CLI.
@discardableResult
func writeExecutableScript(_ script: String, to file: URL) throws -> URL {
    try script.write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    return file
}
