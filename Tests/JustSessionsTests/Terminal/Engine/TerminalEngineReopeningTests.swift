import Foundation
import Testing
@testable import JustSessions

/// Tabs reopened at launch open with the engine chosen now. The engine is not saved with a tab: reopening happens at
/// a new launch, and like every tab opened then, a reopened tab takes the engine chosen in Settings, even when the tab
/// had another before the app quit.
@MainActor
struct TerminalEngineReopeningTests {
    @Test(arguments: TerminalEngine.allCases)
    func aTabReopenedAtLaunchOpensWithTheEngineChosenNowNotTheOneItHadBeforeQuitting(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine.otherEngine)
        defer { sandbox.tearDown() }
        let onThisMac = sandbox.conversation()
        let onSSHHost = sandbox.conversation(host: .ssh("devbox"))
        RemoteHostList(hosts: ["devbox"]).save(to: sandbox.userDefaults)
        let lastLaunch = sandbox.makeStore(listing: [onThisMac, onSSHHost])
        lastLaunch.launch(onThisMac, action: .resume)
        lastLaunch.launch(onSSHHost, action: .resume)
        lastLaunch.openPlainTerminal(in: sandbox.projectLocation)
        // Nothing is selected, so no reopened tab starts.
        lastLaunch.selectTerminal(nil)
        let savedTabs = lastLaunch.reopenableTabs
        try #require(savedTabs.count == 3)
        #expect(lastLaunch.terminalSessions.allSatisfy { $0.engine == engine.otherEngine })
        lastLaunch.closeAllTerminals()

        sandbox.engineStore.setEngine(engine)
        let thisLaunch = sandbox.makeStore()
        thisLaunch.beginReopening(savedTabs)
        thisLaunch.replaceConversations(on: .ssh("devbox"), with: [onSSHHost])
        thisLaunch.replaceConversations(on: .thisMac, with: [onThisMac])

        #expect(thisLaunch.terminalSessions.count == 3)
        #expect(thisLaunch.terminalSessions.allSatisfy { $0.isWaitingToBeShown })
        for tab in thisLaunch.terminalSessions {
            #expect(tab.engine == engine, "\(tab.displayTitle)")
            #expect(engine.draws(tab.terminalView), "\(tab.displayTitle)")
        }
    }
}
