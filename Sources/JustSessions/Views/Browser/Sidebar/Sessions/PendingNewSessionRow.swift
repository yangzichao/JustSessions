import SwiftUI

struct PendingNewSessionRow: View {
    @ObservedObject var terminal: TerminalSession
    let provider: ConversationProvider
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            SidebarSessionRowLayout(provider: provider, isSelected: isSelected) {
                Text(terminal.displayTitle)
                    .italic()
                    .foregroundStyle(isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(ThemePalette.secondaryText))
            } trailing: {
                TerminalStatusIndicator(session: terminal)
            }
            .sidebarRowHighlight(isSelected: isSelected, selectionProvider: provider)
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help("\(provider.rawValue) has not saved this session yet · click to open its terminal")
        .accessibilityLabel("\(terminal.displayTitle), \(provider.rawValue), open terminal, not saved yet")
    }
}
