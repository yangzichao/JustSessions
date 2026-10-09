import SwiftUI

/// One open terminal in the tab bar, drawn as in Chrome: every tab is one width, which narrows as more tabs open, with
/// its × inside. The selected tab takes its terminal's background and runs down into it; the others sit on the bar,
/// parted by short lines. A split's two tabs are half as wide and join into one shape, as in Chrome: while the split
/// shows, both take the selected tab's look, and while it does not, pointing at either lights both.
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
    /// The pointer is over the other tab of this tab's split, which lights this one too.
    let isSplitPartnerHovered: Bool
    /// The line that parts this tab from the one before. It hides beside a tab drawing a shape of its own, and between
    /// a split's two tabs.
    let showsLeadingSeparator: Bool
    /// The color of the tab's group, which outlines the tab while it is active.
    let groupColor: ThemeColor
    /// The split items this tab's context menu offers, or nil for none.
    let splitMenu: TerminalTabSplitMenu?
    /// Starts a new session or a plain terminal in the tab's group, first in its context menu, as Chrome's tab menu
    /// starts with New tab.
    let newSessionMenu: ProjectNewSessionMenu
    let onHoverChange: (Bool) -> Void
    let onSelect: () -> Void
    let onRename: (Conversation) -> Void
    let onSplitAction: (TerminalTabSplitAction) -> Void
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
                }
                // The padding is inside the button, so a click anywhere in the tab but its × selects it.
                .padding(.leading, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(ThemePlainButtonStyle(showsHover: false))
            .help(helpText)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .contextMenu {
                newSessionMenu
                Divider()
                if session.isPlainTerminal {
                    splitMenuItems
                    Button("Close terminal…", systemImage: "xmark", role: .destructive, action: onClose)
                } else {
                    Button("Rename", systemImage: "pencil") {
                        if let conversation = session.conversation { onRename(conversation) }
                    }
                    .disabled(session.conversation == nil)
                    if let conversation = session.conversation {
                        Divider()
                        ConversationSharingMenuItems(selections: [ConversationExportSelection(conversation: conversation, title: session.displayTitle)])
                        Divider()
                    }
                    splitMenuItems
                    Button("End session…", systemImage: "xmark", role: .destructive, action: onClose)
                }
            }

            if showsCloseButton {
                TerminalTabCloseButton(title: session.displayTitle, action: onClose)
            }
        }
        // One weight for every tab, as in Chrome: the active tab stands out by its color and outline.
        .font(.system(size: 12, weight: .medium))
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
                splitSide: splitSide
            )
        }
        .onHover { isHovering in
            isHovered = isHovering
            onHoverChange(isHovering)
        }
        .onboardingTourStop(isSelected ? .keepRunning : nil)
        .onboardingTourStop(isSelected ? .splitView : nil)
    }

    /// The split view entries, as Chrome's tab menu offers them, each a submenu but the first.
    @ViewBuilder private var splitMenuItems: some View {
        switch splitMenu {
        case .newSplitWithSelectedTab:
            Button("New split view with current tab", systemImage: "rectangle.split.2x1") {
                onSplitAction(.newSplitWithSelectedTab)
            }
            Divider()
        case .addTabToNewSplit(let candidates):
            Menu {
                ForEach(candidates) { candidate in
                    Button(candidate.menuTitle) { onSplitAction(.addToNewSplit(candidate.id)) }
                }
            } label: {
                Label("Add tab to new split view", systemImage: "rectangle.split.2x1")
            }
            .disabled(candidates.isEmpty)
            Divider()
        case .moveIntoShownSplit:
            Menu {
                Button("Swap with left view", systemImage: "rectangle.lefthalf.inset.filled") {
                    onSplitAction(.moveIntoShownSplit(swappingWith: .left))
                }
                Button("Swap with right view", systemImage: "rectangle.righthalf.inset.filled") {
                    onSplitAction(.moveIntoShownSplit(swappingWith: .right))
                }
            } label: {
                Label("Move tab into split view", systemImage: "rectangle.split.2x1")
            }
            Divider()
        case .arrangeSplit:
            Menu {
                Button("Separate views", systemImage: "arrow.up.left.and.arrow.down.right") {
                    onSplitAction(.separateViews)
                }
                Divider()
                Button("Close left view", systemImage: "xmark") { onSplitAction(.closeView(.left)) }
                Button("Close right view", systemImage: "xmark") { onSplitAction(.closeView(.right)) }
                Divider()
                Button("Reverse views", systemImage: "arrow.left.arrow.right") { onSplitAction(.reverseViews) }
            } label: {
                Label("Arrange split view", systemImage: "rectangle.split.2x1")
            }
            Divider()
        case nil:
            EmptyView()
        }
    }

    /// A narrow tab hides its × until active or pointed at, as in Chrome, so its title keeps the room.
    private var showsCloseButton: Bool {
        isActive || isHovered || width >= WorkspaceTabMetrics.minimumWidthForCloseButton
    }

    /// A split's tab's title says which view it is, as Chrome's split tabs do; nil keeps the title's own label.
    private var splitAccessibilityLabel: Text? {
        switch splitSide {
        case .left: Text("\(session.displayTitle) - Left view")
        case .right: Text("\(session.displayTitle) - Right view")
        case nil: nil
        }
    }

    /// The tab's title and details.
    private var helpText: Text {
        Text("Show \(session.displayTitle)") + Text(verbatim: "\n" + details)
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
