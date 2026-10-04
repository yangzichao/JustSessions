import SwiftUI

extension ConversationSidebarView {
    @ViewBuilder
    var projectList: some View {
        let selectedConversations = selectedConversations
        let onboardingTourProjectID = onboardingTourProjectID

        ScrollViewReader { scrollProxy in
            SidebarSelectionScrollView(
                isFocused: $isSidebarListFocused,
                onDismissSelection: dismissSidebarSelection
            ) {
                LazyVStack(alignment: .leading, spacing: SidebarIndentGuide.rowSpacing) {
                    ForEach(hostSections) { section in
                        hostHeading(for: section)
                            .padding(.top, 14)
                            .padding(.bottom, 4)

                        if section.projects.isEmpty {
                            SidebarEmptyHostNote(message: SidebarEmptyHostMessage(
                                host: section.host,
                                refreshStatus: store.hostRefreshStatuses[section.host],
                                isSearching: isSearching,
                                recencyFilter: recencyFilter
                            ))
                            .onboardingTourStop(section.host == .thisMac ? .noSessionsYet : nil)
                        }

                        let parentLabels = ProjectParentLabels(projectsOnOneHost: section.projects)
                        ForEach(section.projects) { project in
                            SidebarProjectSection(
                                store: store,
                                project: project,
                                parentLabel: parentLabels.label(for: project),
                                isExpanded: isExpanded(project),
                                isOnboardingTourProject: project.id == onboardingTourProjectID,
                                projectSelection: projectSelection,
                                sessionSelection: sessionSelection,
                                selectedConversations: selectedConversations,
                                onToggleExpansion: { projectExpansion.toggle(project.id) },
                                onClickProject: { handleProjectClick(project) },
                                onNewSession: { provider in
                                    store.launchNewSessionFromProject(provider: provider, projectPath: project.projectPath)
                                },
                                onClickConversation: handleConversationClick,
                                onSelectPendingNewSession: selectTab,
                                onRenameConversation: onRenameConversation,
                                onRenameProject: { onRenameProject(project) },
                                onRemoveSelectedProjects: removeSelectedProjects,
                                onRequestDeletion: onRequestDeletion
                            )
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 12)
            }
            .task(id: projectToReveal) {
                guard let projectToReveal else { return }
                withAnimation { scrollProxy.scrollTo(projectToReveal, anchor: .center) }
                self.projectToReveal = nil
            }
        }
    }
}
