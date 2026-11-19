import SwiftUI

struct SessionSplitMenuItems: View {
    let store: ConversationStore
    let conversation: Conversation

    var body: some View {
        let row = SidebarDraggedRow.session(conversation)
        if let shownOrientation = store.shownSplitOrientation {
            let places = [TerminalSplit.Side.left, .right].map { TerminalDropPlace.split($0, shownOrientation) }
            if places.allSatisfy({ store.dropPlace(for: row, at: $0) != nil }) {
                ForEach([TerminalSplit.Side.left, .right], id: \.self) { side in
                    replaceButton(side, shownOrientation, row: row)
                }
            }
        } else if store.selectedTerminalID != nil {
            ForEach([TerminalSplit.Orientation.sideBySide, .stacked], id: \.self) { orientation in
                let place = TerminalDropPlace.split(.right, orientation)
                if store.dropPlace(for: row, at: place) == place {
                    newSplitButton(orientation, place: place, row: row)
                }
            }
        }
    }

    @ViewBuilder
    private func newSplitButton(_ orientation: TerminalSplit.Orientation, place: TerminalDropPlace, row: SidebarDraggedRow) -> some View {
        let action = { store.showDroppedRow(row, at: place) }
        if orientation == .sideBySide {
            Button("Open in split on the right", systemImage: orientation.systemImage, action: action)
        } else {
            Button("Open in split below", systemImage: orientation.systemImage, action: action)
        }
    }

    @ViewBuilder
    private func replaceButton(_ side: TerminalSplit.Side, _ orientation: TerminalSplit.Orientation, row: SidebarDraggedRow) -> some View {
        let systemImage = orientation.swapWithViewSystemImage(side)
        let action = { store.showDroppedRow(row, at: .split(side, orientation)) }
        switch (orientation, side) {
        case (.sideBySide, .left): Button("Open in left view", systemImage: systemImage, action: action)
        case (.sideBySide, .right): Button("Open in right view", systemImage: systemImage, action: action)
        case (.stacked, .left): Button("Open in top view", systemImage: systemImage, action: action)
        case (.stacked, .right): Button("Open in bottom view", systemImage: systemImage, action: action)
        }
    }
}
