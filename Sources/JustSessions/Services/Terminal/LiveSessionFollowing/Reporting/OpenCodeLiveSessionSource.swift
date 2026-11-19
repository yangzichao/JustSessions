import Foundation

struct OpenCodeLiveSessionSource: LiveSessionSource {
    let reporting: LiveSessionReporting
    var databaseFile = OpenCodeAdapter.standardDatabaseFile()
    var provider: ConversationProvider { .opencode }

    func currentSession(ofCLIProcessID processID: Int32) -> LiveCLISession? {
        guard let report = reporting.report(forProcessID: processID),
            let sessionID = report.sessionID, provider.isValidSessionID(sessionID)
        else { return nil }
        return LiveCLISession(sessionID: sessionID, file: nil)
    }

    func isSaved(_ session: LiveCLISession) -> Bool {
        (try? OpenCodeDatabase.containsTopLevelSession(session.sessionID, in: databaseFile)) ?? false
    }
}
