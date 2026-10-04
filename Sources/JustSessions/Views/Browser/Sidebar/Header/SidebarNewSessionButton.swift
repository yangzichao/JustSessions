import SwiftUI

/// The sidebar's primary action, a filled + at the end of the header line, larger than the icons beside it.
struct SidebarNewSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ThemePalette.inkForeground)
                .frame(width: 24, height: 24)
                .background(ThemePalette.ink, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("New session (⌘N)")
        .accessibilityLabel("New session")
    }
}
