import AppKit
import Observation
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct ConversationMapHoverTests {
    @MainActor
    @Observable
    final class Link {
        var conversation: Conversation?
        init(_ conversation: Conversation?) { self.conversation = conversation }
    }

    private struct Host: View {
        let link: Link
        let model: ConversationOutlineModel
        let store: ConversationStore
        let hover: ConversationMapHover

        var body: some View {
            ConversationMapView(model: model, conversation: link.conversation, provider: .codex, store: store, hover: hover)
        }
    }

    @MainActor
    private final class Fixture {
        let settings: IsolatedUserDefaults
        let window: NSWindow
        let link: Link
        let model = ConversationOutlineModel(checkInterval: .milliseconds(20), minimumReadInterval: .milliseconds(40))
        let hover = ConversationMapHover()

        init(conversation: Conversation) throws {
            _ = NSApplication.shared
            WindowAnimations.disable()
            settings = try IsolatedUserDefaults()
            let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
            link = Link(conversation)
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: ConversationMapMetrics.columnWidth, height: 400),
                styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: Host(link: link, model: model, store: store, hover: hover)
                    .environment(\.ignoresWindowOcclusion, true))
            window.makeKeyAndOrderFront(nil)
        }

        func pointAtTheLastBlock() throws {
            let outline = try #require(model.outline)
            let index = outline.blocks.count - 1
            let y = ConversationMapMetrics.verticalInset + CGFloat(outline.rowStarts[index]) * ConversationMapMetrics.naturalRowPitch + 1
            hover.show(
                ConversationMapHover.Card(
                    blockIndex: index, revision: outline.revision, speaker: "Codex", timestamp: nil,
                    snippet: outline.blocks[index].snippet, letter: nil, top: 0, bandMinY: y - 1,
                    bandHeight: 1, trailingInset: 0),
                at: CGPoint(x: 10, y: y))
        }

        func tearDown() {
            window.contentView = nil
            window.close()
            settings.removeSuite()
        }
    }

    @Test func aStillPointersCardFollowsTheGrowingOutline() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        defer { files.remove() }
        let fixture = try Fixture(conversation: files.conversation)
        defer { fixture.tearDown() }
        try await expectEventually { fixture.model.outline?.blocks.count == 5 }
        try fixture.pointAtTheLastBlock()
        let first = try #require(fixture.hover.card)

        try files.append(ConversationOutlineModelTests.record(5))

        try await expectEventually { fixture.model.outline?.blocks.count == 6 }
        try await expectEventually { fixture.hover.card?.revision == fixture.model.outline?.revision }
        #expect(fixture.hover.card?.revision != first.revision)
        #expect(fixture.hover.card?.blockIndex == 4)
        #expect(fixture.hover.card?.snippet == fixture.model.outline?.blocks[4].snippet)
    }

    @Test func aRelinkTakesTheCardAway() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        let empty = try TranscriptPagingFixture(count: 0)
        defer {
            files.remove()
            empty.remove()
        }
        let fixture = try Fixture(conversation: files.conversation)
        defer { fixture.tearDown() }
        try await expectEventually { fixture.model.outline?.blocks.count == 5 }
        try fixture.pointAtTheLastBlock()

        fixture.link.conversation = empty.conversation

        try await expectEventually { fixture.model.outline?.rowCount == 0 }
        try await expectEventually { fixture.hover.card == nil }
    }
}
