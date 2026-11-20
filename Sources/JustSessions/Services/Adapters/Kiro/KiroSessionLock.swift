import Foundation

/// What Kiro CLI writes while a CLI has a session open, and removes when it exits: `<id>.lock` beside a V2 session's
/// files, `.lock` in a V3 session's folder, holding `{"pid":…,"started_at":"…"}` (Kiro CLI 2.16.2 and 2.34.0). Its
/// process is the CLI's chat process for V2 and its terminal UI for V3, under the process a tab started.
///
/// While the process runs, `kiro-cli chat --delete-session` reports a V2 session deleted and keeps it, and deletes a V3
/// session's folder that the running CLI then writes again from its next turn (Kiro CLI 2.34.0).
struct KiroSessionLock: Equatable, Sendable {
    static let maximumByteCount = 4_096
    private static let processStartToleranceAfterStartedAt: TimeInterval = 5

    let processID: Int32
    let startedAt: Date?

    static func file(forSessionFile sourceFile: URL) -> URL {
        KiroV3Session.isMessagesFile(sourceFile)
            ? sourceFile.deletingLastPathComponent().appendingPathComponent(".lock")
            : sourceFile.deletingPathExtension().appendingPathExtension("lock")
    }

    static func heldLock(forSessionFile sourceFile: URL) -> KiroSessionLock? {
        guard let lock = KiroSessionLock(file: file(forSessionFile: sourceFile)), lock.isHeld else { return nil }
        return lock
    }

    init(processID: Int32, startedAt: Date?) {
        self.processID = processID
        self.startedAt = startedAt
    }

    init?(file: URL) {
        guard file.isPlainFileNotLinkOrPipe,
            let handle = try? FileHandle(forReadingFrom: file)
        else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: Self.maximumByteCount + 1), data.count <= Self.maximumByteCount,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let processID = (object["pid"] as? NSNumber)?.int32Value, processID > 1
        else { return nil }
        self.init(processID: processID, startedAt: (object["started_at"] as? String).flatMap(Self.date(from:)))
    }

    var isHeld: Bool {
        RunningProcessInfo.isRunning(processID) && !processIDWasReusedByNewerProcess
    }

    private var processIDWasReusedByNewerProcess: Bool {
        guard let startedAt, let processStart = RunningProcessInfo.startDate(of: processID) else { return false }
        return processStart > startedAt.addingTimeInterval(Self.processStartToleranceAfterStartedAt)
    }

    /// `2026-10-23T21:24:39.474246Z` (V2) or `2026-10-24T22:09:20.390Z` (V3), to the second.
    static func date(from text: String) -> Date? {
        guard text.count >= 19 else { return nil }
        return ISO8601DateFormatter().date(from: String(text.prefix(19)) + "Z")
    }
}
