import Foundation

/// Reads Claude Code's live process registry: one JSON file per running `claude` process, named by its pid.
struct ClaudeLiveSessionRegistry: Sendable {
    let sessionsDirectory: URL

    init(configurationDirectory: URL = ClaudeAdapter().configurationDirectory) {
        self.sessionsDirectory = configurationDirectory.appendingPathComponent("sessions")
    }

    func record(forProcessID processID: Int32) -> ClaudeLiveSessionRecord? {
        guard processID > 0,
              let data = try? Data(contentsOf: sessionsDirectory.appendingPathComponent("\(processID).json")) else {
            return nil
        }
        return ClaudeLiveSessionRecord(jsonData: data)
    }

    /// The record of the first process in `processIDs` that has one, e.g. the CLI a wrapper script started.
    func firstRecord(amongProcessIDs processIDs: [Int32]) -> ClaudeLiveSessionRecord? {
        processIDs.lazy.compactMap { record(forProcessID: $0) }.first
    }
}
