import SwiftUI

/// One open terminal in the tab bar, drawn as in Chrome: every tab is one width, which narrows as more tabs open, with
/// its × inside. The selected tab takes its terminal's background and runs down into it; the others sit on the bar,
/// parted by short lines. A split's two tabs are half as wide and join into one shape, as in Chrome: while the split
/// shows, both take the selected tab's look, and while it does not, pointing at either lights both. The two tabs of a
/// split across projects each keep a shape of their own, in their project's color, inside the split's container; see
/// `TerminalSplitAcrossProjectsSection`.
struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    /// Named once SSH hosts are added, whichever host the tab runs on.
    let hostDisplayName: String?
    let width: CGFloat
    /// The selected tab, the one with the keyboard.
    let isSelected: Bool
    /// Drawn as the selected tab: it is selected, or in the shown split with the selected tab, as Chrome's
    /// `Tab::IsActive` holds for both tabs of the active split.
    let isActive: Bool
    /// The tab's side of its split, or nil for a tab in no split.
    let splitSide: TerminalSplit.Side?
    /// How the tab's split lays out its views, which names its side for VoiceOver: left or right, or top or bottom.
    let splitOrientation: TerminalSplit.Orientation
    /// A tab of a split across projects draws a shape of its own rather than joining its split's other tab.
    var drawsOwnShape = false
    /// The pointer is over the other tab of this tab's split, which lights this one too.
    let isSplitPartnerHovered: Bool
    /// The line that parts this tab from the one before. It hides beside a tab drawing a shape of its own, and between
    /// a split's two tabs.
    let showsLeadingSeparator: Bool
    /// The color of the tab's group, which outlines the tab while it is active.
    let groupColor: ThemeColor
    /// Closing the tab deletes its session; see `ConversationStore.deletesSessionWhenClosed(_:)`.
    var deletesSessionWhenClosed = false
    /// What a right-click anywhere on the tab offers, its × included.
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
                        // Only the title's label, so the tab still reads its status first.
                        .accessibilityLabel(replacingWith: splitAccessibilityLabel)
                    if deletesSessionWhenClosed { DeletedWhenTabClosesIndicator() }
                }
                // The padding is inside the button, so a click anywhere in the tab but its × selects it.
                .padding(.leading, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(ThemePlainButtonStyle(showsHover: false))
            // The tab's hover card shows its whole title and details; see `TabHoverCardOverlay`.
            .accessibilityHint(Text(verbatim: details))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if showsCloseButton {
                TerminalTabCloseButton(title: session.displayTitle, action: onClose)
            }
        }
        // One weight for every tab, as in Chrome: the active tab stands out by its color and outline.
        .font(ThemeFont.callout.weight(.medium))
        .foregroundStyle(isActive ? ThemePalette.ink : ThemePalette.secondaryText)
        // An active tab sits on the terminal's background, which can be dark in a light window or the reverse.
        .environment(\.colorScheme, isActive ? terminalPalette.colorScheme : colorScheme)
        // Without the ×, the title ends as far from the tab's edge as it starts.
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

    /// A narrow tab hides its × until active or pointed at, as in Chrome, so its title keeps the room.
    private var showsCloseButton: Bool {
        isActive || isHovered || width >= WorkspaceTabMetrics.minimumWidthForCloseButton
    }

    /// A split's tab's title says which view it is, as Chrome's split tabs do; nil keeps the title's own label.
    private var splitAccessibilityLabel: Text? {
        switch (splitSide, splitOrientation) {
        case (.left, .sideBySide): Text("\(session.displayTitle) - Left view")
        case (.right, .sideBySide): Text("\(session.displayTitle) - Right view")
        case (.left, .stacked): Text("\(session.displayTitle) - Top view")
        case (.right, .stacked): Text("\(session.displayTitle) - Bottom view")
        case (nil, _): nil
        }
    }

    /// Where the tab runs and what it runs, such as "JustSessions · Claude Code · Resume".
    private var details: String {
        [projectDisplayName, hostDisplayName, session.provider?.rawValue ?? "Terminal", session.action?.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

private extension View {
    /// Replaces the view's accessibility label with `label`, or leaves it as it is when there is none.
    @ViewBuilder
    func accessibilityLabel(replacingWith label: Text?) -> some View {
        if let label {
            accessibilityLabel(label)
        } else {
            self
        }
    }
}
