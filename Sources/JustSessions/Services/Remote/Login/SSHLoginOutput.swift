import Foundation

/// What the login's `ssh` prints, kept in a file in the login's private folder and read a part at a time: what came
/// since the last question goes with the next one, such as a second factor's options, which `ssh` prints rather than
/// passing them to the askpass program. Questions themselves, and what is typed, never reach it.
final class SSHLoginOutput: @unchecked Sendable {
    let file: URL
    private let lock = NSLock()
    private var readLength = 0

    static let routineLinePrefixes = ["Warning: Permanently added"]

    init?(file: URL) {
        guard FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
        else { return nil }
        self.file = file
    }

    func makeWritingHandle() -> FileHandle? {
        try? FileHandle(forWritingTo: file)
    }

    var all: String {
        (try? Data(contentsOf: file)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    func newText() -> String? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let newData = lock.withLock {
            defer { readLength = data.count }
            return data.count > readLength ? data[readLength...] : Data()
        }
        let lines = String(decoding: newData, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in !line.isEmpty && !Self.routineLinePrefixes.contains { line.hasPrefix($0) } }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
