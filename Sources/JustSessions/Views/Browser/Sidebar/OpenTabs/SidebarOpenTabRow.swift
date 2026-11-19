import SwiftUI

struct SidebarOpenTabRow<MenuItems: View>: View {
    @ObservedObject var tab: TerminalSession
    let projectDisplayName: String
    var splitSide: TerminalSplit.Side? = nil
    var splitOrientation: TerminalSplit.Orientation = .sideBySide
    let isSelected: Bool
    let onSelect: () -> Void
    @ViewBuilder let menuItems: () -> MenuItems

    static var height: CGFloat { InterfaceScale.points(28) }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                toolIcon
                    .font(ThemeFont.glyph(.control, weight: .medium))
                    .frame(width: InterfaceScale.points(14))
                Text(verbatim: tab.displayTitle)
                    .font(ThemeFont.callout.weight(isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let splitSide {
                    Image(systemName: splitOrientation.swapWithViewSystemImage(splitSide))
                        .font(ThemeFont.glyph(.control))
                        .foregroundStyle(ThemePalette.secondaryText)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 6)
                TerminalStatusIndicator(session: tab)
            }
            .padding(.horizontal, 10)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: isSelected, selectionProvider: tab.provider)
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help(Text("Show \(tab.displayTitle)") + Text(verbatim: "\n" + projectContext + "\n" + tab.projectPath))
        .accessibilityLabel(Text(verbatim: "\(tab.displayTitle), \(projectContext)"))
        .accessibilityValue(splitAccessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu { menuItems() }
    }

    private var splitAccessibilityValue: Text {
        switch (splitSide, splitOrientation) {
        case (.left, .sideBySide): Text("Left view")
        case (.right, .sideBySide): Text("Right view")
        case (.left, .stacked): Text("Top view")
        case (.right, .stacked): Text("Bottom view")
        case (nil, _): Text(verbatim: "")
        }
    }

    private var projectContext: String {
        if let destination = tab.host.sshDestination {
            return "\(projectDisplayName) · \(destination)"
        }
        return projectDisplayName
    }

    @ViewBuilder
    private var toolIcon: some View {
        if let provider = tab.provider {
            provider.iconImage(size: 10)
                .foregroundStyle(provider.tintColor)
        } else {
            Image(systemName: "terminal")
                .foregroundStyle(ThemePalette.secondaryText)
        }
    }
}
