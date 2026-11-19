import AppKit
import Testing

@testable import JustSessions

/// Which reader ⌘D, ⌘', and ⇧⌘' reach in a workspace window (TRM-74, RDR-49): the selected tab, nothing while a split
/// chooser has the keyboard, and never a tab while none is selected, when the preview's reader answers instead.
@MainActor
@Suite(.serialized)
struct TerminalTabBookmarksRoutingTests {
    @Test func theSelectedTabAnswersButNotWhileASplitChooserOrNoTabHasTheKeyboard() async throws {
        WindowAnimations.disable()
        let workspace = try SplitWorkspace(engine: .swiftTerm)
        defer { workspace.close() }
        let store = workspace.store
        // Plain terminals, so a command that reaches one says so at once.
        let first = workspace.open()
        let second = workspace.open()
        store.selectTerminal(first.id)
        try await workspace.show()
        let registry = TranscriptBookmarkTargetRegistry.shared

        try #require(registry.target(in: workspace.window)).toggleBookmark()
        #expect(first.bookmarkNotices.notice == .plainTerminal)
        #expect(second.bookmarkNotices.notice == nil)
        first.bookmarkNotices.dismiss()

        store.openSplitChooser()
        try await workspace.settleLayout()
        try #require(store.selectsShownSplitChooser)
        #expect(registry.target(in: workspace.window) == nil)

        // Selecting the tab beside the chooser gives it the keyboard back.
        store.selectTerminal(first.id)
        try await workspace.settleLayout()
        try #require(registry.target(in: workspace.window)).toggleBookmark()
        #expect(first.bookmarkNotices.notice == .plainTerminal)
        first.bookmarkNotices.dismiss()

        // With no tab selected the preview's reporter is the window's; here it shows no session, so nothing answers.
        store.closeSplitChooser(try #require(store.shownSplitChooser).id)
        store.selectTerminal(nil)
        try await workspace.settleLayout()
        #expect(registry.target(in: workspace.window) == nil)
    }
}
