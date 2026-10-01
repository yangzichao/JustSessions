import SwiftUI

/// Project selection and disclosure have separate controls so expanding a project preserves a multi-selection.
struct SidebarProjectRow: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let isExpanded: Bool
    let projectSelection: ProjectMultiSelection
    let onToggleExpansion: () -> Void
    let onClick: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let onRename: () -> Void
    let onDeleteSessions: () -> Void
    let onRemoveSelectedProjects: () -> Void

    @State private var isHovered = false

    private var isSelected: Bool { projectSelection.contains(project.id) }
    private var rowHeight: CGFloat { parentLabel == nil ? 30 : 40 }

    var body: some View {
        let activitySummary = store.activitySummary(forProjectDirectoryKey: project.id)

        HStack(spacing: 0) {
            Button(action: onToggleExpansion) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeOut(duration: 0.12), value: isExpanded)
                    .frame(width: 27, height: rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse project" : "Expand project")
            .accessibilityLabel("\(isExpanded ? "Collapse" : "Expand") \(project.displayName)")

            Button(action: onClick) {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let parentLabel {
                            Text(parentLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if project.isPinned { PinnedIndicator() }
                    if let status = activitySummary.mostPressingStatus {
                        SessionStatusIndicator(status: status, description: activitySummary.summary)
                    }
                }
                .padding(.trailing, 6)
                .frame(height: rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .help("\(project.location.copyablePath) · ⌘-click to select multiple projects; Shift-click to select a range")
            .accessibilityLabel("\(project.displayName)\(project.isPinned ? ", pinned" : ""), \(CountedNoun.phrase(count: project.sessionCount, singular: "session")), \(activitySummary.runningCount == 0 ? "none running" : activitySummary.summary)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            sessionCountOrNewSessionMenu
                .padding(.trailing, 8)
        }
        .background(SidebarRowBackground(isSelected: isSelected, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .contextMenu {
            if isSelected && projectSelection.hasMultipleSelected {
                SelectedProjectsContextMenu(
                    selectedCount: projectSelection.selectedProjectIDs.count,
                    onRemove: onRemoveSelectedProjects
                )
            } else {
                ProjectContextMenu(
                    store: store,
                    project: project,
                    onNewSession: onNewSession,
                    onRename: onRename,
                    onDeleteSessions: onDeleteSessions
                )
            }
        }
    }

    /// The session count gives way to the + menu while the pointer is over the row.
    private var sessionCountOrNewSessionMenu: some View {
        ZStack(alignment: .trailing) {
            Text(project.sessionCount.formatted())
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 0 : 1)
            ProjectNewSessionMenu(
                project: project,
                providers: store.newSessionProviders(on: project.host),
                showsTitle: false,
                onStart: onNewSession,
                onOpenTerminal: { store.openPlainTerminal(in: project.location) }
            )
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
    }
}
