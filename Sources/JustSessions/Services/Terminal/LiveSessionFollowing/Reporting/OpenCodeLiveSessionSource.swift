import Foundation

/// The session an OpenCode CLI shows, as the app's plugin reports it; see `OpenCodeLiveSessionPlugin`.
struct OpenCodeLiveSessionSource: LiveSessionSource {
    let reporting: LiveSessionReporting
    var databaseFile = OpenCodeAdapter.standardDatabaseFile()
    var provider: ConversationProvider { .opencode }

    func currentSession(ofCLIProcessID processID: Int32) -> LiveCLISession? {
        guard let report = reporting.report(forProcessID: processID),
              let sessionID = report.sessionID, provider.isValidSessionID(sessionID) else { return nil }
        return LiveCLISession(sessionID: sessionID, file: nil)
    }

    /// OpenCode also shows a subagent's session, which is never listed.
    func isSaved(_ session: LiveCLISession) -> Bool {
        (try? OpenCodeDatabase.containsTopLevelSession(session.sessionID, in: databaseFile)) ?? false
    }
}
