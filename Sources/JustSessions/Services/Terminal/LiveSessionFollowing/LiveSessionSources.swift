import Foundation

enum LiveSessionSources {
    /// Antigravity's own log, and the reports of the app's Pi and OpenCode extensions when the app starts them with
    /// one; see `LiveSessionReporting`.
    static func thisMac() -> [any LiveSessionSource] {
        let reportedSources: [any LiveSessionSource] = LiveSessionReporting.thisApp.map { reporting in
            [PiLiveSessionSource(reporting: reporting), OpenCodeLiveSessionSource(reporting: reporting)]
        } ?? []
        return [AntigravityLiveConversationSource()] + reportedSources
    }
}
