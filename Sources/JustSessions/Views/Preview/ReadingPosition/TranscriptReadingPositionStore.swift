import Foundation

enum TranscriptReadingPosition: Equatable {
    case bottom
    /// The entry's stable reading ID and the distance already read within that entry.
    case entry(index: Int, offset: CGFloat)

    func resolved(in transcript: TranscriptContent) -> TranscriptReadingPosition {
        guard case .entry(let index, let offset) = self,
              let firstIndex = transcript.positionIDs.first, let lastIndex = transcript.positionIDs.last else { return self }
        if transcript.usesEntryIDsForPositions {
            let resolvedIndex = transcript.positionIDs.first(where: { $0 >= index }) ?? lastIndex
            return .entry(index: resolvedIndex, offset: resolvedIndex == index ? offset : 0)
        }
        return .entry(
            index: min(max(index, firstIndex), lastIndex),
            offset: (firstIndex...lastIndex).contains(index) ? offset : 0
        )
    }

    var entryIndex: Int? {
        guard case .entry(let index, _) = self else { return nil }
        return index
    }
}

/// Owned by the preview pane, so replacing a session's transcript view does not discard its reading position.
/// Scroll updates do not publish view changes. Positions last for this window's lifetime.
@MainActor
final class TranscriptReadingPositionStore {
    private var positionsByConversationID: [String: TranscriptReadingPosition] = [:]

    func position(for conversationID: String) -> TranscriptReadingPosition? {
        positionsByConversationID[conversationID]
    }

    func record(_ position: TranscriptReadingPosition, for conversationID: String) {
        positionsByConversationID[conversationID] = position
    }
}
