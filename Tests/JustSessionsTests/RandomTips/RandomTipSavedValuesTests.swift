import Testing

@testable import JustSessions

struct RandomTipSavedValuesTests {
    @Test func savedTipNamesStayTheSame() {
        #expect(
            RandomTip.allCases.map(\.rawValue) == [
                "resumeSession", "newSessionAnyCLI", "readWithoutRunning", "keepRunning", "reopenTabs", "unseenTurn",
                "sshHosts", "checkSSHHost", "splitView", "dragIntoSplitView", "selectSeveralSessions", "branch",
                "waitingForYouFilter", "notifications", "readingWindow", "pin", "openProjectInEditor", "archiveProject",
                "showSubagents", "dragTabToNewWindow", "collapseTabGroup", "backAndForward", "tabByPosition",
                "hideSidebar", "textSize", "dropFiles", "ghosttyEngine", "computerUse",
            ])
    }
}
