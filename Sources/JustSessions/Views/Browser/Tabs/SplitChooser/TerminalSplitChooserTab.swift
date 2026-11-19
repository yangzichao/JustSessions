import SwiftUI

struct TerminalSplitChooserTab: View {
    let width: CGFloat
    let isSelected: Bool
    let isActive: Bool
    let side: TerminalSplit.Side
    let orientation: TerminalSplit.Orientation
    let isPartnerHovered: Bool
    let showsLeadingSeparator: Bool
    let groupColor: ThemeColor
    let menuItems: TerminalTabSplitMenuItems
    let onHoverChange: (Bool) -> Void
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var accessibilityLabel: Text {
        switch (side, orientation) {
        case (.left, .sideBySide): Text("Choose a tab - Left view")
        case (.right, .sideBySide): Text("Choose a tab - Right view")
        case (.left, .stacked): Text("Choose a tab - Top view")
        case (.right, .stacked): Text("Choose a tab - Bottom view")
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: orientation.systemImage)
                        .font(ThemeFont.glyph(.control, weight: .semibold))
                        .frame(width: InterfaceScale.points(10), height: InterfaceScale.points(10))
                        .accessibilityHidden(true)
                    TerminalTabTitle(localizedTitle: "Choose a tab")
                        .accessibilityLabel(accessibilityLabel)
                }
                .padding(.leading, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(ThemePlainButtonStyle(showsHover: false))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(ThemeFont.glyph(.small, weight: .bold))
                        .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(16))
                        .contentShape(Circle())
                }
                .buttonStyle(ThemePlainButtonStyle(cornerRadius: nil))
                .help("Close this view")
                .accessibilityLabel("Close this view")
            }
        }
        .font(ThemeFont.callout.weight(.medium))
        .foregroundStyle(isActive ? ThemePalette.ink : ThemePalette.secondaryText)
        .environment(\.colorScheme, isActive ? terminalPalette.colorScheme : colorScheme)
        .padding(.trailing, showsCloseButton ? 6 : 10)
        .frame(width: width, height: WorkspaceTabMetrics.height)
        .background {
            WorkspaceTabBackground(
                isSelected: isActive,
                isHovered: isHovered || isPartnerHovered,
                showsLeadingSeparator: showsLeadingSeparator,
                groupColor: groupColor,
                splitSide: side
            )
        }
        .contextMenu { menuItems }
        .onHover { isHovering in
            isHovered = isHovering
            onHoverChange(isHovering)
        }
    }

    private var showsCloseButton: Bool {
        isActive || isHovered || width >= WorkspaceTabMetrics.minimumWidthForCloseButton
    }
}
