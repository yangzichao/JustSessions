import Foundation

extension ConversationStore {
    func closingQuestion(
        forTabs ids: [UUID],
        tabCloseChoices: TabCloseChoicesByHost,
        plainTerminalCloseChoice: PlainTerminalCloseChoice
    ) -> SeveralTabsClosingQuestion {
        let tabs = terminalSessions.filter { ids.contains($0.id) && !deletesSessionWhenClosed($0) }
            .map { (need: $0.closingNeed, tabCloseChoice: tabCloseChoices.choice(for: $0.host)) }
        return SeveralTabsClosingQuestion(tabs: tabs, plainTerminalCloseChoice: plainTerminalCloseChoice)
    }

    func closeTabs(_ ids: [UUID], endingTmuxSessions: Bool) {
        closeTabs(ids) { _ in endingTmuxSessions }
    }

    func closeTabs(_ ids: [UUID], as tabCloseChoices: TabCloseChoicesByHost) {
        closeTabs(ids) { tabCloseChoices.choice(for: $0).endsTmuxSessionWithoutAsking ?? true }
    }

    private func closeTabs(_ ids: [UUID], endingTmuxSessionOn endsTmuxSession: (SessionHost) -> Bool) {
        let tabsToClose = terminalSessions.filter { ids.contains($0.id) }
        let selectedLast = tabsToClose.filter { $0.id != selectedTerminalID } + tabsToClose.filter { $0.id == selectedTerminalID }
        for tab in selectedLast {
            if deletesSessionWhenClosed(tab) {
                closeTabDeletingItsSession(tab.id)
                continue
            }
            switch tab.closingNeed {
            case .nothingStarted:
                closeTerminal(tab.id)
            case .canKeepCLIRunning:
                closeTerminal(tab.id, endingTmuxSession: endsTmuxSession(tab.host))
            case .alreadyEnded, .plainTerminal, .cliStopsWithTab:
                closeTerminal(tab.id, endingTmuxSession: true)
            }
        }
    }
}
