import Foundation

extension ConversationStore {
    /// Cycles through open terminals, wrapping at either end. From a preview, enters at the nearest end.
    func selectAdjacentTerminal(movingForward: Bool) {
        guard !terminalSessions.isEmpty else { return }
        let destinationIndex: Int
        if let selectedIndex = terminalSessions.firstIndex(where: { $0.id == selectedTerminalID }) {
            let offset = movingForward ? 1 : -1
            destinationIndex = (selectedIndex + offset + terminalSessions.count) % terminalSessions.count
        } else {
            destinationIndex = movingForward ? 0 : terminalSessions.count - 1
        }
        selectTerminal(terminalSessions[destinationIndex].id)
    }

    /// Browser-style number shortcuts: 1 through 8 select that position, and 9 always selects the last tab.
    func selectTerminal(shortcutNumber: Int) {
        guard (1...9).contains(shortcutNumber), !terminalSessions.isEmpty else { return }
        let destinationIndex = shortcutNumber == 9 ? terminalSessions.count - 1 : shortcutNumber - 1
        guard terminalSessions.indices.contains(destinationIndex) else { return }
        selectTerminal(terminalSessions[destinationIndex].id)
    }
}
