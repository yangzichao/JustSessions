import SwiftUI

/// The split view entries a tab's context menu offers, as Chrome's tab menu offers them.
enum TerminalTabSplitMenu {
    /// Another tab in no split, while the selected tab is in none: it can open in a new split with the selected tab.
    case newSplitWithSelectedTab
    /// The selected tab, in no split: any of these tabs, every other tab in no split, can open in a new split with it.
    case addTabToNewSplit(candidates: [TerminalTabSplitCandidate])
    /// A tab in no split, while the selected tab is in a split: it can take the place of either of that split's tabs.
    case moveIntoShownSplit
    /// A tab in a split, shown or not: its split can be separated, either of its views closed, or its views reversed.
    case arrangeSplit
}

/// A tab that can open in a new split with the selected tab, named in the menu by its title and its project's name, so
/// tabs of one title in different projects can be told apart.
struct TerminalTabSplitCandidate: Identifiable {
    let session: TerminalSession
    let projectDisplayName: String

    var id: UUID { session.id }

    /// Such as "Fix the build · JustSessions": the user's own names, joined as the tab's tooltip joins its details.
    @MainActor var menuTitle: String {
        [session.displayTitle, projectDisplayName].joined(separator: " · ")
    }
}

/// What a tab's split view entries ask for; see `TerminalTabSplitMenu`.
enum TerminalTabSplitAction {
    case newSplitWithSelectedTab
    /// Opens the given tab in a new split with the selected tab.
    case addToNewSplit(UUID)
    case moveIntoShownSplit(swappingWith: TerminalSplit.Side)
    case separateViews
    case closeView(TerminalSplit.Side)
    case reverseViews
}

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
    /// The split items this tab's context menu offers, or nil for none.
    let splitMenu: TerminalTabSplitMenu?
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
        .font(.system(size: 12, weight: isActive ? .semibold : .medium))
        .foregroundStyle(isActive ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(.secondary))
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
                splitSide: splitSide
            )
        }
        .onHover { isHovering in
            isHovered = isHovering
            onHoverChange(isHovering)
        }
        .onboardingTourStop(isSelected ? .keepRunning : nil)
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
