import Foundation

/// The session a Pi CLI is in, as the app's extension reports it; see `PiLiveSessionExtension`.
struct PiLiveSessionSource: LiveSessionSource {
    let reporting: LiveSessionReporting
    var provider: ConversationProvider { .pi }

    func currentSession(ofCLIProcessID processID: Int32) -> LiveCLISession? {
        guard let report = reporting.report(forProcessID: processID),
              let sessionID = report.sessionID, provider.isValidSessionID(sessionID) else { return nil }
        return LiveCLISession(sessionID: sessionID, file: report.sessionFile)
    }

    /// Pi writes a new session's file only after its first prompt.
    func isSaved(_ session: LiveCLISession) -> Bool {
        session.file.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }
}
