import Foundation

/// The conversation an Antigravity CLI is in, from the log it holds open; see `AntigravityCLILog`. Its open SQLite file
/// is no such evidence: Antigravity closes it once the conversation is idle, and keeps two open for a while after
/// `/resume` or `/fork`. Each CLI's log is found once, with `lsof`, and then read as it grows.
final class AntigravityLiveConversationSource: LiveSessionSource, @unchecked Sendable {
    /// A CLI whose log was not found yet, such as one that just started, is looked up again after this long.
    static let logLookupRetryInterval: TimeInterval = 10

    let configurationDirectory: URL
    private let logFileOfProcess: @Sendable (Int32) -> URL?
    private let lock = NSLock()
    private var cliLogs: [Int32: CLILog] = [:]

    private struct CLILog {
        let processStartDate: Date?
        let file: URL?
        let lookedUpAt: Date
        var tail = AntigravityCLILogTail()
    }

    var provider: ConversationProvider { .antigravity }

    init(
        configurationDirectory: URL = AntigravityAdapter.defaultConfigurationDirectory,
        logFileOfProcess: (@Sendable (Int32) -> URL?)? = nil
    ) {
        self.configurationDirectory = configurationDirectory
        self.logFileOfProcess = logFileOfProcess ?? { processID in
            ProcessOpenFileReader().openFilePaths(ofProcessIDs: [processID])[processID]?
                .first { AntigravityCLILog.isCLILog(atPath: $0, configurationDirectory: configurationDirectory) }
                .map { URL(fileURLWithPath: $0) }
        }
    }

    func currentSession(ofCLIProcessID processID: Int32) -> LiveCLISession? {
        guard processID > 0 else { return nil }
        var cliLog = cliLog(ofProcessID: processID)
        if let file = cliLog.file { cliLog.tail.readNewLines(of: file) }
        lock.withLock { cliLogs[processID] = cliLog }
        return cliLog.tail.conversationID.map { conversationID in
            LiveCLISession(
                sessionID: conversationID,
                file: configurationDirectory.appendingPathComponent("conversations/\(conversationID).db")
            )
        }
    }

    /// A new conversation's file starts out without the rows that name it.
    func isSaved(_ session: LiveCLISession) -> Bool {
        session.file.flatMap(AntigravitySQLiteReader.localSession(at:))?.sessionID == session.sessionID
    }

    /// The process's log as last read, or a new lookup for a process seen for the first time, one that reuses an
    /// earlier process's id, or one whose log was not found a while ago.
    private func cliLog(ofProcessID processID: Int32) -> CLILog {
        let processStartDate = RunningProcessInfo.startDate(of: processID)
        if let cliLog = lock.withLock({ cliLogs[processID] }), cliLog.processStartDate == processStartDate,
           cliLog.file != nil || Date.now.timeIntervalSince(cliLog.lookedUpAt) < Self.logLookupRetryInterval {
            return cliLog
        }
        let file = logFileOfProcess(processID)
        lock.withLock { cliLogs = cliLogs.filter { RunningProcessInfo.isRunning($0.key) } }
        return CLILog(processStartDate: processStartDate, file: file, lookedUpAt: .now)
    }
}
