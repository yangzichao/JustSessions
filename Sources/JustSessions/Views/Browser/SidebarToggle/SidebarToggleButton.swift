import SwiftUI

struct SidebarToggleButton: View {
    static let width: CGFloat = 28

    @Binding var isSidebarHidden: Bool

    private var actionName: LocalizedStringKey {
        isSidebarHidden ? "Show sidebar" : "Hide sidebar"
    }

    private var helpText: LocalizedStringKey {
        isSidebarHidden ? "Show sidebar (⌘B)" : "Hide sidebar (⌘B)"
    }

    var body: some View {
        Button {
            isSidebarHidden.toggle()
        } label: {
            Image(systemName: "sidebar.left")
                .font(ThemeFont.glyph(.titleBar))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: Self.width, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle())
        .help(helpText)
        .accessibilityLabel(actionName)
        .onboardingTourStop(isSidebarHidden ? nil : .hideSidebar)
    }
}
