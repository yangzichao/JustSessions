import SwiftUI

/// Confirms a `SessionDeletionRequest`, then hands it to the store.
private struct SessionDeletionDialog: ViewModifier {
    @ObservedObject var store: ConversationStore
    @Binding var request: SessionDeletionRequest?

    func body(content: Content) -> some View {
        content.confirmationDialog("Delete sessions?", isPresented: Binding(isPresenting: $request)) {
            switch request {
            case .conversation(let conversation):
                deleteButton(title: SessionDeletionConfirmationText.oneSessionButtonTitle) {
                    store.delete(conversation)
                }
            case .conversations(let conversations):
                deleteButton(for: store.deletionPlan(for: conversations)) {
                    store.deleteConversations(conversations)
                }
            case .project(let projectPath):
                deleteButton(for: store.deletionPlan(for: projectPath)) {
                    store.deleteSessions(in: projectPath)
                }
            case nil:
                EmptyView()
            }
            Button("Cancel", role: .cancel) { request = nil }
        } message: {
            if let request {
                Text(message(for: request))
            }
        }
    }

    private func deleteButton(title: String, delete: @escaping () -> Void) -> some View {
        Button(title, role: .destructive) {
            delete()
            request = nil
        }
    }

    /// Names how many sessions the plan deletes, and is disabled when that is none.
    private func deleteButton(for plan: SessionDeletionPlan, delete: @escaping () -> Void) -> some View {
        deleteButton(title: SessionDeletionConfirmationText.buttonTitle(for: plan), delete: delete)
            .disabled(!plan.hasDeletableConversations)
    }

    private func message(for request: SessionDeletionRequest) -> String {
        switch request {
        case .conversation(let conversation):
            SessionDeletionConfirmationText.message(forDeleting: conversation)
        case .conversations(let conversations):
            SessionDeletionConfirmationText.message(forDeletingSelectionWith: store.deletionPlan(for: conversations))
        case .project(let projectPath):
            SessionDeletionConfirmationText.message(
                forDeletingProjectAt: ProjectLocation(key: projectPath),
                plan: store.deletionPlan(for: projectPath)
            )
        }
    }
}

extension View {
    func sessionDeletionDialog(for request: Binding<SessionDeletionRequest?>, store: ConversationStore) -> some View {
        modifier(SessionDeletionDialog(store: store, request: request))
    }
}
