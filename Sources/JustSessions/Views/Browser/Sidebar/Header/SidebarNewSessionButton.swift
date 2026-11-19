import SwiftUI

struct SidebarNewSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(ThemeFont.callout.weight(.semibold))
                .foregroundStyle(ThemePalette.ink)
                .frame(width: InterfaceScale.points(26), height: InterfaceScale.points(26))
                .background(ThemePalette.trackFill, in: RoundedRectangle(.control))
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: .control))
        .help("New session (⌘N)")
        .accessibilityLabel("New session")
    }
}
