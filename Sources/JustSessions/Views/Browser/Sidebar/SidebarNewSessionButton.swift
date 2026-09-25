import SwiftUI

/// The sidebar's primary action, drawn as a row so it leads the list without a full-width filled button.
struct SidebarNewSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.accentColor, in: Circle())
                Text("New session")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 4)
                Text("⌘N")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: false)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .help("Start Claude Code, Codex, or Antigravity in a project folder")
        .padding(.horizontal, 8)
    }
}
