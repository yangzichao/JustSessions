import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// A labelled bookmark's label above its message in the reader (RDR-51): on the speaker's line where the message starts
/// a turn, so the message keeps its height, else on a line of its own; a bookmark without a label, or none, changes
/// nothing.
@MainActor
struct TranscriptBookmarkLabelTests {
    private static func height(of entry: TranscriptEntry, bookmark: MessageBookmark?) -> CGFloat {
        let view = TranscriptEntryView(entry: entry, assistantName: "Codex", assistantNameColor: ConversationProvider.codex.textColor)
            .environment(\.transcriptSearchEntryIndex, entry.id)
            .environment(\.transcriptBookmarkLetters, TranscriptBookmarkLetters(bookmark.map { [$0] } ?? []))
            .frame(width: 600)
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    private static func bookmark(on entry: TranscriptEntry, label: String?) -> MessageBookmark {
        var bookmark = MessageBookmark(letter: "a", entryID: entry.id, kind: .assistant, snippet: "")
        bookmark.label = label
        return bookmark
    }

    @Test func aLabelWithinATurnTakesALineOfItsOwnAndNothingElseChangesTheHeight() {
        let entry = TranscriptEntry(id: 7, content: .assistantMessage("Fixed the build."), timestamp: nil, startsTurn: false)

        let plain = Self.height(of: entry, bookmark: nil)
        let lettered = Self.height(of: entry, bookmark: Self.bookmark(on: entry, label: nil))
        let labelled = Self.height(of: entry, bookmark: Self.bookmark(on: entry, label: "testing"))

        #expect(lettered == plain)
        #expect(labelled > plain + 10 && labelled < plain + 30)
    }

    @Test func aLabelWhereATurnStartsSitsOnTheSpeakersLine() {
        let entry = TranscriptEntry(id: 3, content: .assistantMessage("Fixed the build."), timestamp: .now, startsTurn: true)

        let plain = Self.height(of: entry, bookmark: nil)
        let labelled = Self.height(of: entry, bookmark: Self.bookmark(on: entry, label: "testing"))

        #expect(abs(labelled - plain) <= 1)
    }

    @Test func aRowThatCantBeBookmarkedNeverShowsOne() {
        let entry = TranscriptEntry(id: 9, content: .toolCalls(["Run make"]), timestamp: nil, startsTurn: false)

        #expect(Self.height(of: entry, bookmark: Self.bookmark(on: entry, label: "testing")) == Self.height(of: entry, bookmark: nil))
    }
}
