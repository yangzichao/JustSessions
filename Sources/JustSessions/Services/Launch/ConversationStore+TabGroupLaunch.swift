import Foundation

/// A tab's right-click menu starts a new session or a plain terminal in the tab's group, so the new tab joins it.
extension ConversationStore {
    /// The project folder of the tab's group, on the group's host. A split's tab from another project shows in the
    /// split's group, so a tab started from it opens there too.
    func groupLocation(of tab: TerminalSession) -> ProjectLocation {
        ProjectLocation(key: tabGroupKey(of: tab))
    }

    func launchNewSession(provider: ConversationProvider, inGroupOf tab: TerminalSession) {
        launchNewSessionFromProject(provider: provider, projectPath: tabGroupKey(of: tab))
    }

    func openPlainTerminal(inGroupOf tab: TerminalSession) {
        openPlainTerminal(in: groupLocation(of: tab))
    }
}
