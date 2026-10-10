import SwiftUI

/// Every loaded entry is laid out, rather than only those near the viewport: the reader keeps only a few pages, at
/// most `TranscriptPagingModel.maximumRetainedPageCount`. A lazy stack estimates the heights of rows it has not laid out
/// and corrects them as they appear. That made scrolling jump, most of all past tall images, and the stack could
/// keep correcting without end inside one update, freezing the window, with images or with text alone.
///
/// Laying out every entry is costly, so the entries are their own view, compared by their inputs. These stay the same
/// while you scroll or search, so SwiftUI leaves the entries, and their layout, alone. Each entry's `id` lets
/// `ScrollViewProxy.scrollTo` bring it into view; nothing asks SwiftUI to track which one is at the top.
struct TranscriptEntriesStack: View, Equatable {
    let transcript: TranscriptContent
    let provider: ConversationProvider
    let positionController: TranscriptScrollPositionController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(transcript.positionedEntries) { positionedEntry in
                let entryIndex = positionedEntry.id
                TranscriptEntryView(entry: positionedEntry.entry, assistantName: provider.rawValue, assistantNameColor: provider.textColor)
                    .environment(\.transcriptSearchEntryIndex, entryIndex)
                    .background(TranscriptEntryPositionMarker(entryIndex: entryIndex, controller: positionController))
                    .id(entryIndex)
            }
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.transcript == rhs.transcript && lhs.provider == rhs.provider && lhs.positionController === rhs.positionController
    }
}
