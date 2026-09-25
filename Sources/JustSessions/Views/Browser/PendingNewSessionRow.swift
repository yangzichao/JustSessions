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
                    .font(.system(size: 11))
                    .foregroundStyle(terminal.provider.tintColor)
                    .frame(width: 14)
                Text(terminal.displayTitle)
                    .italic()
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 3)
                TerminalStatusIndicator(session: terminal)
            }
            .font(.system(size: 11, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.leading, 32)
            .padding(.trailing, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("\(terminal.provider.rawValue) has not saved this session yet · click to open its terminal")
        .accessibilityLabel("\(terminal.displayTitle), \(terminal.provider.rawValue), open terminal, not saved yet")
    }
}
