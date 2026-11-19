import AppKit
import SwiftUI

struct TranscriptTextSurface: NSViewRepresentable, Equatable {
    let content: TranscriptTextContent
    let selectionKey: TranscriptTextSelectionKey
    let copyRole: TranscriptTextCopyRole
    let navigationRevision: Int
    let positionController: TranscriptScrollPositionController?
    let selectionCoordinator: TranscriptTextSelectionCoordinator?

    func makeNSView(context: Context) -> TranscriptTextView { TranscriptTextView() }

    func updateNSView(_ view: TranscriptTextView, context: Context) {
        view.setSelection(coordinator: selectionCoordinator, key: selectionKey, copyRole: copyRole)
        view.setContent(content)
        view.selectedSearchRange = content.selectedMatchRange
        view.navigationRevision = navigationRevision
        if content.selectedMatchRange == nil {
            view.revealSelectedRange = nil
        } else {
            let entryIndex = selectionKey.entryIndex
            view.revealSelectedRange = { [weak positionController] textView, range in
                positionController?.revealSearchMatch(in: textView, range: range, entryIndex: entryIndex) ?? false
            }
            view.needsLayout = true
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TranscriptTextView, context: Context) -> CGSize? {
        nsView.measuredSize(width: proposal.width)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.content == rhs.content && lhs.selectionKey == rhs.selectionKey && lhs.copyRole == rhs.copyRole
            && lhs.navigationRevision == rhs.navigationRevision && lhs.positionController === rhs.positionController
            && lhs.selectionCoordinator === rhs.selectionCoordinator
    }
}
