import SwiftUI

/// Lists a "New session" or "Branch" tab under its project until the CLI saves a session the sidebar can show instead.
struct PendingNewSessionRow: View {
    @ObservedObject var terminal: TerminalSession
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            SidebarSessionRowLayout(provider: terminal.provider, isSelected: isSelected) {
                Text(terminal.displayTitle)
                    .italic()
                    .foregroundStyle(isSelected ? .primary : .secondary)
            } trailing: {
                TerminalStatusIndicator(session: terminal)
            }
        }
        .buttonStyle(.plain)
        .help("\(terminal.provider.rawValue) has not saved this session yet · click to open its terminal")
        .accessibilityLabel("\(terminal.displayTitle), \(terminal.provider.rawValue), open terminal, not saved yet")
    }
}
