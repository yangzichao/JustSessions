import SwiftUI

/// Confirms a `SessionDeletionRequest`, then hands it to the store.
private struct SessionDeletionDialog: ViewModifier {
    @Environment(\.locale) private var locale
    @ObservedObject var store: ConversationStore
    @Binding var request: SessionDeletionRequest?

    func body(content: Content) -> some View {
        content.confirmationDialog("Delete sessions?", isPresented: Binding(isPresenting: $request)) {
            switch request {
            case .conversation(let conversation):
                if store.cliEndingBeforeDeletion(of: conversation) != nil {
                    deleteButton(title: AppLocalization.string("Close and delete session", language: language)) {
                        store.closeAndDelete(conversation)
                    }
                } else {
                    deleteButton(title: AppLocalization.string("Delete session", language: language)) {
                        store.delete(conversation)
                    }
                }
            case .conversations(let conversations):
                deleteButton(for: store.deletionPlan(for: conversations)) {
                    store.deleteConversations(conversations)
                }
            case .project(let projectPath):
                deleteButton(for: store.deletionPlan(for: projectPath)) {
                    store.deleteSessions(in: projectPath)
                }
            case .projectRemoval(let projectPath):
                let plan = store.deletionPlan(for: projectPath)
                deleteButton(title: SessionDeletionConfirmationText.projectRemovalButtonTitle(for: plan, language: language)) {
                    store.deleteSessionsAndRemoveProject(projectPath)
                }
                .disabled(!plan.hasDeletableConversations)
            case .selectedProjectsRemoval(let projectPaths):
                let plan = store.deletionPlan(forProjects: projectPaths)
                deleteButton(title: SessionDeletionConfirmationText.selectedProjectsRemovalButtonTitle(
                    projectCount: projectPaths.count, plan: plan, language: language
                )) {
                    store.deleteSessionsAndRemoveProjects(projectPaths)
                }
                .disabled(!plan.hasDeletableConversations)
            case nil:
                EmptyView()
            }
            Button("Cancel", role: .cancel) { request = nil }
        } message: {
            if let request {
                Text(message(for: request))
            }
        }
        .dismissesOnClickOutside(item: $request)
    }

    private func deleteButton(title: String, delete: @escaping () -> Void) -> some View {
        Button(title, role: .destructive) {
            delete()
            request = nil
        }
    }

    /// Names how many sessions the plan deletes, and is disabled when that is none.
    private func deleteButton(for plan: SessionDeletionPlan, delete: @escaping () -> Void) -> some View {
        deleteButton(title: SessionDeletionConfirmationText.buttonTitle(for: plan, language: language), delete: delete)
            .disabled(!plan.hasDeletableConversations)
    }

    private func message(for request: SessionDeletionRequest) -> String {
        switch request {
        case .conversation(let conversation):
            message(forDeleting: conversation)
        case .conversations(let conversations):
            SessionDeletionConfirmationText.message(forDeletingSelectionWith: store.deletionPlan(for: conversations), language: language)
        case .project(let projectPath):
            SessionDeletionConfirmationText.message(
                forDeletingProjectAt: ProjectLocation(key: projectPath),
                plan: store.deletionPlan(for: projectPath), language: language
            )
        case .projectRemoval(let projectPath):
            SessionDeletionConfirmationText.message(
                forDeletingProjectAt: ProjectLocation(key: projectPath),
                plan: store.deletionPlan(for: projectPath), removesProjectFromSidebar: true, language: language
            )
        case .selectedProjectsRemoval(let projectPaths):
            SessionDeletionConfirmationText.message(
                forRemovingSelectedProjectsAt: projectPaths.map(ProjectLocation.init(key:)),
                plan: store.deletionPlan(forProjects: projectPaths), language: language
            )
        }
    }

    /// For a session a tab or tmux runs, also says what Close and delete ends first.
    private func message(forDeleting conversation: Conversation) -> String {
        let cliEnding = store.cliEndingBeforeDeletion(of: conversation)
        return SessionDeletionConfirmationText.message(
            forDeleting: conversation,
            plan: store.deletionPlan(for: [conversation], endingTheirCLIs: cliEnding != nil),
            cliEnding: cliEnding,
            language: language
        )
    }

    private var language: AppInterfaceLanguage { AppInterfaceLanguage(identifier: locale.identifier) }
}

extension View {
    func sessionDeletionDialog(for request: Binding<SessionDeletionRequest?>, store: ConversationStore) -> some View {
        modifier(SessionDeletionDialog(store: store, request: request))
    }
}
