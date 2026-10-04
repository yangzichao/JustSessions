import Foundation
import Testing
@testable import JustSessions

/// The pane layout survives a quit through the saved tabs: docked tabs are saved by their place in the saved
/// order, previews by session id, and both come back on the relaunch's new tab ids.
@MainActor
struct WorkspacePaneReopeningTests {
    @Test func savedLayoutsRoundTripOntoNewTabIDsAndPruneWhatNeverCameBack() throws {
        let oldA = UUID()
        let oldB = UUID()
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(.terminal(oldA), on: .trailing, of: .selection)
            .docking(.terminal(oldB), on: .bottom, of: .terminal(oldA))
            .docking(.preview("session-1"), on: .leading, of: .selection)

        let saved = try #require(SavedPaneLayout(layout: layout, savedPositionsByTabID: [oldA: 0, oldB: 1]))
        let decoded = try JSONDecoder().decode(SavedPaneLayout.self, from: JSONEncoder().encode(saved))
        #expect(decoded == saved)

        let newA = UUID()
        let newB = UUID()
        let restored = decoded.restored(tabIDsBySavedPosition: [0: newA, 1: newB], listedConversationIDs: ["session-1"])
        #expect(restored == layout
            .movingToCenter(.terminal(newA), of: .terminal(oldA))
            .movingToCenter(.terminal(newB), of: .terminal(oldB)))

        // A tab that never reopened and a session no longer listed lose their panes.
        let pruned = decoded.restored(tabIDsBySavedPosition: [0: newA], listedConversationIDs: [])
        #expect(pruned.panes == [.selection, .terminal(newA)])
    }

    @Test func layoutsWithNothingWorthSavingAreNotSavedAndCorruptDataRestoresUnsplit() throws {
        #expect(SavedPaneLayout(layout: .selectionOnly, savedPositionsByTabID: [:]) == nil)
        let unsaveableTab = WorkspacePaneLayout.selectionOnly.docking(.terminal(UUID()), on: .trailing, of: .selection)
        #expect(SavedPaneLayout(layout: unsaveableTab, savedPositionsByTabID: [:]) == nil)

        let duplicatedSelection = SavedPaneLayout.split(
            isHorizontal: true, fraction: 0.5, leading: .selection, trailing: .selection
        )
        #expect(duplicatedSelection.restored(tabIDsBySavedPosition: [:], listedConversationIDs: []) == .selectionOnly)
        let duplicatedTab = SavedPaneLayout.split(
            isHorizontal: true, fraction: 0.5,
            leading: .split(isHorizontal: false, fraction: 0.5, leading: .selection, trailing: .tab(0)),
            trailing: .tab(0)
        )
        #expect(duplicatedTab.restored(tabIDsBySavedPosition: [0: UUID()], listedConversationIDs: []) == .selectionOnly)
    }

    @Test func tabsSavedBeforePanesExistedStillReopenAsPlainTabs() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let oldFormat = #"{"tabs":[{"projectDirectoryKey":"\#(sandbox.project.path)","wasSelected":true}]}"#
        sandbox.userDefaults.set(Data(oldFormat.utf8), forKey: TerminalTabsToReopen.userDefaultsKey)

        let loaded = TerminalTabsToReopen.load(from: sandbox.userDefaults)
        #expect(loaded.paneLayout == nil)
        #expect(loaded.tabs == [.plainTerminal(in: sandbox.projectLocation, wasSelected: true)])

        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.reopenTabsFromLastQuit(from: TabsSavedAtQuit(), isEnabled: true)
        #expect(store.terminalSessions.count == 1)
        #expect(store.paneLayout == .selectionOnly)
    }

    @Test func aDockedPlainTerminalsPaneComesBackOnTheRelaunchsNewTabID() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let quitting = sandbox.makeStore()
        quitting.openPlainTerminal(in: sandbox.projectLocation)
        quitting.openPlainTerminal(in: sandbox.projectLocation)
        let docked = quitting.terminalSessions[1]
        quitting.dockPane(.terminal(docked.id), on: .bottom, of: .selection)
        let savedAtQuit = TabsSavedAtQuit()
        quitting.saveTabsForNextLaunch(to: savedAtQuit)
        quitting.closeAllTerminals()

        let relaunched = sandbox.makeStore()
        defer { relaunched.closeAllTerminals() }
        relaunched.reopenTabsFromLastQuit(from: savedAtQuit, isEnabled: true)

        #expect(relaunched.terminalSessions.count == 2)
        let newDockedID = relaunched.terminalSessions[1].id
        #expect(newDockedID != docked.id)
        #expect(relaunched.paneLayout.panes == [.selection, .terminal(newDockedID)])
        #expect(relaunched.pendingSavedPaneLayout == nil)
    }

    /// A previewed session is not listed the instant the app launches; its pane waits for the first listing.
    @Test func aPreviewPaneWaitsForItsSessionsFirstListingBeforeRestoring() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let quitting = sandbox.makeStore()
        quitting.replaceConversations(on: .thisMac, with: [conversation])
        quitting.dockPane(.preview(conversation.id), on: .trailing, of: .selection)
        let savedAtQuit = TabsSavedAtQuit()
        quitting.saveTabsForNextLaunch(to: savedAtQuit)

        let relaunched = sandbox.makeStore()
        relaunched.reopenTabsFromLastQuit(from: savedAtQuit, isEnabled: true)
        #expect(relaunched.paneLayout == .selectionOnly)
        #expect(relaunched.pendingSavedPaneLayout != nil)

        relaunched.replaceConversations(on: .thisMac, with: [conversation])

        #expect(relaunched.paneLayout.panes == [.selection, .preview(conversation.id)])
        #expect(relaunched.pendingSavedPaneLayout == nil)
    }
}
