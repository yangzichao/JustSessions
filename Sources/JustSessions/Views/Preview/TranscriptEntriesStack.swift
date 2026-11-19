import SwiftUI

/// Every loaded entry is laid out, rather than only those near the viewport: the reader keeps only a few pages, at
/// most `TranscriptPagingModel.maximumRetainedPageCount`. A lazy stack estimates the heights of rows it has not laid out
/// and corrects them as they appear. That made scrolling jump, most of all past tall images, and the stack could
/// keep correcting without end inside one update, freezing the window, with images or with text alone.
///
/// Laying out every entry is costly, so the entries are their own view, compared by their inputs. These stay the same
/// while you scroll or search, so SwiftUI leaves the entries, and their layout, alone. Each entry's `id` lets
/// `ScrollViewProxy.scrollTo` bring it into view; nothing asks SwiftUI to track which one is at the top. A bookmark's
/// letter is an overlay reading only `transcriptBookmarkLetters` and the reader's hover card.
struct TranscriptEntriesStack: View, Equatable {
    let transcript: TranscriptContent
    let provider: ConversationProvider
    let positionController: TranscriptScrollPositionController

    var body: some View {
        TranscriptEntryGeometryLayout(entryIndices: transcript.positionIDs, controller: positionController) {
            ForEach(transcript.positionedEntries) { positionedEntry in
                let entryIndex = positionedEntry.id
                TranscriptEntryView(entry: positionedEntry.entry, assistantName: provider.rawValue, assistantNameColor: provider.textColor)
                    .overlay(alignment: .topLeading) {
                        // Only your messages and the CLI's replies can be bookmarked; other rows get no marker view at all.
                        if MessageBookmark.Kind(positionedEntry.entry.content) != nil {
                            TranscriptBookmarkMarker(
                                entryID: entryIndex,
                                topPadding: TranscriptEntryView.topPadding(startsTurn: positionedEntry.entry.startsTurn))
                        }
                    }
                    .environment(\.transcriptSearchEntryIndex, entryIndex)
                    .id(entryIndex)
            }
        }
        .background(TranscriptEntryGeometryObserver(controller: positionController))
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.transcript == rhs.transcript && lhs.provider == rhs.provider && lhs.positionController === rhs.positionController
    }
}
