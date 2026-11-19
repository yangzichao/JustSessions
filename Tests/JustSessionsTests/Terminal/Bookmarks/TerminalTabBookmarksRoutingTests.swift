import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TerminalTabBookmarksRoutingTests {
    @Test func theSelectedTabAnswersButNotWhileASplitChooserOrNoTabHasTheKeyboard() async throws {
        WindowAnimations.disable()
        let workspace = try SplitWorkspace(engine: .swiftTerm)
        defer { workspace.close() }
        let store = workspace.store
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

        store.selectTerminal(first.id)
        try await workspace.settleLayout()
        try #require(registry.target(in: workspace.window)).toggleBookmark()
        #expect(first.bookmarkNotices.notice == .plainTerminal)
        first.bookmarkNotices.dismiss()

        store.closeSplitChooser(try #require(store.shownSplitChooser).id)
        store.selectTerminal(nil)
        try await workspace.settleLayout()
        #expect(registry.target(in: workspace.window) == nil)
    }
}
