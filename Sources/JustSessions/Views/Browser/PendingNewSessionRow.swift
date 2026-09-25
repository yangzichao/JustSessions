import SwiftUI

/// Lists a "New session" tab under its project until the CLI saves a session the sidebar can show instead.
struct PendingNewSessionRow: View {
    @ObservedObject var terminal: TerminalSession
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: terminal.provider.symbolName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(terminal.provider.tintColor)
                    .frame(width: 14)
                Text(terminal.displayTitle)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .italic()
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                TerminalStatusIndicator(session: terminal)
            }
            .padding(.leading, 28)
            .padding(.trailing, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .help("\(terminal.provider.rawValue) has not saved this session yet · click to open its terminal")
        .accessibilityLabel("\(terminal.displayTitle), \(terminal.provider.rawValue), open terminal, not saved yet")
    }
}
