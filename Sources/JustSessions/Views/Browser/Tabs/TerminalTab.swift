import SwiftUI

struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    let hostDisplayName: String?
    let width: CGFloat
    let isSelected: Bool
    let isActive: Bool
    let splitSide: TerminalSplit.Side?
    let splitOrientation: TerminalSplit.Orientation
    var drawsOwnShape = false
    let isSplitPartnerHovered: Bool
    let showsLeadingSeparator: Bool
    let groupColor: ThemeColor
    var deletesSessionWhenClosed = false
    let menuItems: TerminalTabMenuItems
    let onHoverChange: (Bool) -> Void
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    TerminalStatusIndicator(session: session)
                    TerminalTabTitle(title: session.displayTitle)
                        .accessibilityLabel(replacingWith: splitAccessibilityLabel)
                    if deletesSessionWhenClosed { DeletedWhenTabClosesIndicator() }
                }
                .padding(.leading, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(ThemePlainButtonStyle(showsHover: false))
            .accessibilityHint(Text(verbatim: details))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if showsCloseButton {
                TerminalTabCloseButton(title: session.displayTitle, action: onClose)
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
                isHovered: isHovered || isSplitPartnerHovered,
                showsLeadingSeparator: showsLeadingSeparator,
                groupColor: groupColor,
                splitSide: drawsOwnShape ? nil : splitSide
            )
        }
        .contextMenu { menuItems }
        .onHover { isHovering in
            isHovered = isHovering
            onHoverChange(isHovering)
        }
        .onboardingTourStop(isSelected ? .keepRunning : nil)
        .onboardingTourStop(isSelected ? .splitView : nil)
    }

    private var showsCloseButton: Bool {
        isActive || isHovered || width >= WorkspaceTabMetrics.minimumWidthForCloseButton
    }

    private var splitAccessibilityLabel: Text? {
        switch (splitSide, splitOrientation) {
        case (.left, .sideBySide): Text("\(session.displayTitle) - Left view")
        case (.right, .sideBySide): Text("\(session.displayTitle) - Right view")
        case (.left, .stacked): Text("\(session.displayTitle) - Top view")
        case (.right, .stacked): Text("\(session.displayTitle) - Bottom view")
        case (nil, _): nil
        }
    }

    private var details: String {
        [projectDisplayName, hostDisplayName, session.provider?.rawValue ?? "Terminal", session.action?.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

extension View {
    @ViewBuilder
    fileprivate func accessibilityLabel(replacingWith label: Text?) -> some View {
        if let label {
            accessibilityLabel(label)
        } else {
            self
        }
    }
}
