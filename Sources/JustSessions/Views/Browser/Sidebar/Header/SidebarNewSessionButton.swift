import SwiftUI

/// The sidebar's primary action: a + on a soft chip at the end of the header line, the same chip as the project
/// filter below it, so it stands out from the plain search icon without outweighing the session list.
struct SidebarNewSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ThemePalette.ink)
                .frame(width: 26, height: 26)
                .background(ThemePalette.trackFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: 7))
        .help("New session (⌘N)")
        .accessibilityLabel("New session")
    }
}
