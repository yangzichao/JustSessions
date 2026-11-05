import SwiftUI

/// A split chooser's half of the split tab it makes with the tab beside it, titled as Chrome titles its split view
/// page's tab: drawn as a split's tab, it joins its tab's half into one shape. A click gives the chooser the keyboard,
/// and its × closes it, leaving its tab full width.
struct TerminalSplitChooserTab: View {
    let width: CGFloat
    /// The chooser has the keyboard.
    let isSelected: Bool
    /// The chooser shows, so it is drawn as the selected tab, as its tab is.
    let isActive: Bool
    let side: TerminalSplit.Side
    /// How the split it makes lays out its views, which names its side for VoiceOver.
    let orientation: TerminalSplit.Orientation
    /// The pointer is over the tab beside it, which lights this half too.
    let isPartnerHovered: Bool
    let showsLeadingSeparator: Bool
    let groupColor: ThemeColor
    /// What a right-click on it offers: its split's entries.
    let menuItems: TerminalTabSplitMenuItems
    let onHoverChange: (Bool) -> Void
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    /// Which view of the split the chooser is, as a split's tab says (`TerminalTab`).
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

    /// As on a terminal's tab: a narrow half hides its × until active or pointed at.
    private var showsCloseButton: Bool {
        isActive || isHovered || width >= WorkspaceTabMetrics.minimumWidthForCloseButton
    }
}
