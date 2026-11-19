import Darwin
import Foundation

final class StandInScripts: @unchecked Sendable {
    static let shared = StandInScripts()

    private static let folderPrefix = "JustSessionsTests-stand-ins-"

    private let folder: URL
    private let lock = NSLock()
    private var copiesByScript: [String: URL] = [:]

    init(temporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        Self.removeFoldersOfEndedRuns(in: temporaryDirectory)
        folder = temporaryDirectory.appendingPathComponent(Self.folderPrefix + String(getpid()), isDirectory: true)
    }

    func link(_ script: String, to file: URL) throws {
        let copy = try self.copy(of: script)
        try? FileManager.default.removeItem(at: file)
        do {
            try FileManager.default.linkItem(at: copy, to: file)
        } catch {
            // A link can't cross volumes; such a file is a copy of its own, which macOS checks on its first run.
            try Self.write(script, to: file)
        }
    }

    private func copy(of script: String) throws -> URL {
        try lock.withLock {
            if let copy = copiesByScript[script] { return copy }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let copy = folder.appendingPathComponent("script-\(copiesByScript.count)")
            try Self.write(script, to: copy)
            copiesByScript[script] = copy
            return copy
        }
    }

    private static func write(_ script: String, to file: URL) throws {
        try script.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    private static func removeFoldersOfEndedRuns(in temporaryDirectory: URL) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)) ?? []
        for name in names where name.hasPrefix(folderPrefix) {
            guard let processID = pid_t(name.dropFirst(folderPrefix.count)), processID != getpid(),
                kill(processID, 0) != 0, errno == ESRCH
            else { continue }
            try? FileManager.default.removeItem(at: temporaryDirectory.appendingPathComponent(name))
        }
    }
}
