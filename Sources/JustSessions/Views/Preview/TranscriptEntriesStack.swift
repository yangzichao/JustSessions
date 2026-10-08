import SwiftUI

/// Every loaded entry is laid out, rather than only those near the viewport: the reader keeps only a few pages, at
/// most `TranscriptPagingModel.maximumRetainedPageCount`. A lazy stack estimates the heights of rows it has not laid out
/// and corrects them as they appear. That made scrolling jump, most of all past tall images, and the stack could
/// keep correcting without end inside one update, freezing the window, with images or with text alone.
///
/// Laying out every entry is costly, so the entries are their own view, compared by their inputs. Scrolling changes the
/// visible entry, which updates `TranscriptScrollView`, but these inputs stay the same, so SwiftUI leaves the entries,
/// and their layout, alone.
struct TranscriptEntriesStack: View, Equatable {
    let transcript: TranscriptContent
    let provider: ConversationProvider
    let positionController: TranscriptScrollPositionController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(transcript.positionedEntries) { positionedEntry in
                let entryIndex = positionedEntry.id
                TranscriptEntryView(entry: positionedEntry.entry, assistantName: provider.rawValue, assistantTint: provider.tintColor)
                    .environment(\.transcriptSearchEntryIndex, entryIndex)
                    .background(TranscriptEntryPositionMarker(entryIndex: entryIndex, controller: positionController))
                    .id(entryIndex)
            }
        }
        .scrollTargetLayout()
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.transcript == rhs.transcript && lhs.provider == rhs.provider && lhs.positionController === rhs.positionController
    }
}
