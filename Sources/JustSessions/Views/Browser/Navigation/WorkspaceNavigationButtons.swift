import SwiftUI

struct WorkspaceNavigationButtons: View {
    static let buttonWidth = SidebarToggleButton.width
    static let width = buttonWidth * 2
    private static let menuDestinationLimit = 15

    let navigation: WorkspaceNavigation

    var body: some View {
        HStack(spacing: 0) {
            button(
                systemImage: "arrow.left",
                actionName: "Back",
                helpText: "Back (⌘[). Right-click to see history.",
                destinations: navigation.backDestinations,
                action: navigation.goBack
            )
            button(
                systemImage: "arrow.right",
                actionName: "Forward",
                helpText: "Forward (⌘]). Right-click to see history.",
                destinations: navigation.forwardDestinations,
                action: navigation.goForward
            )
        }
    }

    private func button(
        systemImage: String,
        actionName: LocalizedStringKey,
        helpText: LocalizedStringKey,
        destinations: [WorkspaceNavigation.Destination],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(ThemeFont.glyph(.titleBar))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: Self.buttonWidth, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle())
        .disabled(destinations.isEmpty)
        .help(helpText)
        .accessibilityLabel(actionName)
        .contextMenu {
            ForEach(destinations.prefix(Self.menuDestinationLimit)) { destination in
                Button {
                    navigation.go(destination)
                } label: {
                    Label(destination.title, systemImage: Self.symbolName(of: destination.location))
                }
            }
        }
    }

    private static func symbolName(of location: WorkspaceLocation) -> String {
        switch location {
        case .tab: "terminal"
        case .conversation: "text.bubble"
        }
    }
}
