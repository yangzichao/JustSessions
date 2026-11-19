import Combine
import Foundation
import Testing

@testable import JustSessions

@MainActor
struct NotificationBellAcrossWindowsTests {
    @Test func listsTabsOfEveryWindowExceptOneShowingInItsWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.second))
        tab.updateCLIActivity(.needsInput(reason: "input needed"))

        #expect(sandbox.first.notificationBellEntries.map(\.source) == [tab.attentionSource])
        #expect(sandbox.first.notificationBellEntries.map(\.reason) == [.needsInput(reason: "input needed")])
        #expect(sandbox.second.notificationBellEntries.map(\.source) == [tab.attentionSource])

        let firstWindowBell = StoreChangeCounter(sandbox.first) { _ = $0.notificationBellEntries }
        let firstWindowChanges = StoreChangeCounter(sandbox.first)
        defer {
            firstWindowBell.cancel()
            firstWindowChanges.cancel()
        }
        sandbox.second.selectTerminal(tab.id)
        #expect(firstWindowBell.count > 0)
        #expect(firstWindowChanges.count == 0)
        #expect(sandbox.first.notificationBellEntries.isEmpty)
        #expect(sandbox.second.notificationBellEntries.isEmpty)

        sandbox.second.selectTerminal(nil)
        #expect(sandbox.first.notificationBellEntries.map(\.source) == [tab.attentionSource])
    }

    @Test func clickingARowShowsTheTabInTheWindowThatHasIt() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.second))
        tab.updateCLIActivity(.needsInput(reason: nil))

        sandbox.first.showSession(fromNotificationBell: try #require(sandbox.first.notificationBellEntries.first))

        #expect(sandbox.second.selectedTerminalID == tab.id)
        #expect(sandbox.first.terminalSessions.isEmpty)
    }

    @Test func clickingARowOfACLIInTmuxWithNoTabReattachesInTheBellsWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tmuxSessionName = TmuxSessionName.forConversation(sandbox.conversation)
        for store in [sandbox.first, sandbox.second] {
            store.setTmuxSessionNames([tmuxSessionName], on: .thisMac)
            store.detachedCLIActivities = [sandbox.conversation.id: .needsInput(reason: nil)]
        }
        let entry = try #require(sandbox.second.notificationBellEntries.first)
        #expect(entry.source == .detachedTmux(conversationID: sandbox.conversation.id))

        sandbox.second.showSession(fromNotificationBell: entry)

        let tab = try #require(sandbox.second.runningTerminal(for: sandbox.conversation))
        #expect(sandbox.second.selectedTerminalID == tab.id)
        #expect(sandbox.first.terminalSessions.isEmpty)
    }

    @Test func aCLIInTmuxReattachedInAnotherWindowIsListedOnlyAsItsTab() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        sandbox.first.detachedCLIActivities = [sandbox.conversation.id: .needsInput(reason: nil)]
        #expect(sandbox.first.notificationBellEntries.map(\.source) == [.detachedTmux(conversationID: sandbox.conversation.id)])

        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.second))
        #expect(sandbox.first.notificationBellEntries.isEmpty)
        tab.updateCLIActivity(.needsInput(reason: nil))
        #expect(sandbox.first.notificationBellEntries.map(\.source) == [tab.attentionSource])
    }
}
