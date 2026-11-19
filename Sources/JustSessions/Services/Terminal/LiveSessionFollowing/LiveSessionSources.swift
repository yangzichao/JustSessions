import Foundation

enum LiveSessionSources {
    static func thisMac() -> [any LiveSessionSource] {
        let reportedSources: [any LiveSessionSource] =
            LiveSessionReporting.thisApp.map { reporting in
                [PiLiveSessionSource(reporting: reporting), OpenCodeLiveSessionSource(reporting: reporting)]
            } ?? []
        return [AntigravityLiveConversationSource()] + reportedSources
    }
}
