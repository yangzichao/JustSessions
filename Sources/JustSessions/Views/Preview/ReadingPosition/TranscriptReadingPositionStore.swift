import Foundation

enum TranscriptReadingPosition: Equatable {
    case bottom
    case entry(index: Int, offset: CGFloat)

    static func startOfEntry(_ index: Int) -> TranscriptReadingPosition {
        .entry(index: index, offset: -TranscriptColumnLayout.topPadding)
    }

    func resolved(in transcript: TranscriptContent) -> TranscriptReadingPosition {
        guard case .entry(let index, let offset) = self,
            let firstIndex = transcript.positionIDs.first, let lastIndex = transcript.positionIDs.last
        else { return self }
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
