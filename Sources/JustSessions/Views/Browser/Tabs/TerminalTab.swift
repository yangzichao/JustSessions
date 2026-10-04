import SwiftUI

/// One open terminal in the tab bar, drawn as in Chrome: every tab is one width, which narrows as more tabs open, with
/// its × inside. The selected tab takes its terminal's background and runs down into it; the others sit on the bar,
/// parted by short lines.
struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let projectDisplayName: String
    /// Named once SSH hosts are added, whichever host the tab runs on.
    let hostDisplayName: String?
    let width: CGFloat
    let isSelected: Bool
    /// The line that parts this tab from the one before. It hides beside the selected or hovered tab.
    let showsLeadingSeparator: Bool
    let onHoverChange: (Bool) -> Void
    let onSelect: () -> Void
    let onRename: (Conversation) -> Void
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
                }
                // The padding is inside the button, so a click anywhere in the tab but its × selects it.
                .padding(.leading, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(ThemePlainButtonStyle(showsHover: false))
            .help(Text("Show \(session.displayTitle)") + Text(verbatim: "\n" + details))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .contextMenu {
                if session.isPlainTerminal {
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
                    Button("End session…", systemImage: "xmark", role: .destructive, action: onClose)
                }
            }

            if showsCloseButton {
                TerminalTabCloseButton(title: session.displayTitle, action: onClose)
            }
        }
        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
        .foregroundStyle(isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(.secondary))
        // The selected tab sits on the terminal's background, which can be dark in a light window or the reverse.
        .environment(\.colorScheme, isSelected ? (terminalPalette.isDark ? .dark : .light) : colorScheme)
        // Without the ×, the title ends as far from the tab's edge as it starts.
        .padding(.trailing, showsCloseButton ? 6 : 10)
        .frame(width: width, height: WorkspaceTabMetrics.height)
        .background {
            WorkspaceTabBackground(isSelected: isSelected, isHovered: isHovered, showsLeadingSeparator: showsLeadingSeparator)
        }
        .onHover { isHovering in
            isHovered = isHovering
            onHoverChange(isHovering)
        }
        .onboardingTourStop(isSelected ? .keepRunning : nil)
    }

    /// A narrow tab hides its × until selected or pointed at, as in Chrome, so its title keeps the room.
    private var showsCloseButton: Bool {
        isSelected || isHovered || width >= WorkspaceTabMetrics.minimumWidthForCloseButton
    }

    /// Where the tab runs and what it runs, such as "JustSessions · Claude Code · Resume".
    private var details: String {
        [projectDisplayName, hostDisplayName, session.provider?.rawValue ?? "Terminal", session.action?.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
