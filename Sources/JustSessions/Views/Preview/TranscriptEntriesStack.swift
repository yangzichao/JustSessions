import SwiftUI

/// A lazy stack estimates the heights of rows it has not laid out and corrects them as they appear. That made scrolling
/// jump, and the stack could keep correcting without end inside one update, freezing the window.
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
