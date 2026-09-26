import AppKit
import SwiftUI

struct ContentView: View {
    private enum DeletionRequest {
        case conversation(Conversation)
        case conversations([Conversation])
        case project(String)
    }

    @StateObject private var store = ConversationStore()
    @State private var searchText = ""
    @State private var recencyFilter: SessionRecencyFilter = .all
    @State private var providerFilter: ConversationProviderFilter = .all
    @State private var renamingConversation: Conversation?
    @State private var renamingProject: ProjectConversationGroup?
    @State private var editedProjectName = ""
    @State private var deletionRequest: DeletionRequest?
    @State private var editedTitle = ""
    @State private var hasStartedScan = false

    var body: some View {
        ConversationBrowserView(
            store: store,
            searchText: $searchText,
            recencyFilter: $recencyFilter,
            providerFilter: $providerFilter,
            onRename: { conversation in
                editedTitle = store.title(for: conversation)
                renamingConversation = conversation
            },
            onDelete: { deletionRequest = .conversation($0) },
            onDeleteConversations: { deletionRequest = .conversations($0) },
            onRenameProject: { project in
                editedProjectName = project.displayName
                renamingProject = project
            },
            onDeleteProjectSessions: { deletionRequest = .project($0) }
        )
        .onAppear {
            if !hasStartedScan {
                hasStartedScan = true
                store.refreshAllHosts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.closeAllTerminals()
        }
        .alert("Rename conversation", isPresented: Binding(
            get: { renamingConversation != nil },
            set: { if !$0 { renamingConversation = nil } }
        )) {
            TextField("Name", text: $editedTitle)
            Button("Cancel", role: .cancel) { renamingConversation = nil }
            Button("Save") {
                if let conversation = renamingConversation { store.rename(conversation, to: editedTitle) }
                renamingConversation = nil
            }
        } message: {
            Text("This changes the display name in JustSessions.")
        }
        .alert("Rename project", isPresented: Binding(
            get: { renamingProject != nil },
            set: { if !$0 { renamingProject = nil } }
        )) {
            TextField("Name", text: $editedProjectName)
            Button("Cancel", role: .cancel) { renamingProject = nil }
            Button("Save") {
                if let project = renamingProject { store.renameProject(project.projectPath, to: editedProjectName) }
                renamingProject = nil
            }
        } message: {
            Text("This changes the display name in JustSessions. The folder stays the same. Leave empty to use the folder name (\(renamingProject?.folderName ?? "")).")
        }
        .confirmationDialog("Delete sessions?", isPresented: Binding(
            get: { deletionRequest != nil },
            set: { if !$0 { deletionRequest = nil } }
        )) {
            switch deletionRequest {
            case .conversation(let conversation):
                Button(SessionDeletionConfirmationText.oneSessionButtonTitle, role: .destructive) {
                    store.delete(conversation)
                    deletionRequest = nil
                }
            case .conversations(let conversations):
                let deletionPlan = store.deletionPlan(for: conversations)
                Button(SessionDeletionConfirmationText.buttonTitle(for: deletionPlan), role: .destructive) {
                    store.deleteConversations(conversations)
                    deletionRequest = nil
                }
                .disabled(!deletionPlan.hasDeletableConversations)
            case .project(let projectPath):
                let deletionPlan = store.deletionPlan(for: projectPath)
                Button(SessionDeletionConfirmationText.buttonTitle(for: deletionPlan), role: .destructive) {
                    store.deleteSessions(in: projectPath)
                    deletionRequest = nil
                }
                .disabled(!deletionPlan.hasDeletableConversations)
            case nil:
                EmptyView()
            }
            Button("Cancel", role: .cancel) { deletionRequest = nil }
        } message: {
            switch deletionRequest {
            case .conversation(let conversation):
                Text(SessionDeletionConfirmationText.message(forDeleting: conversation))
            case .conversations(let conversations):
                Text(SessionDeletionConfirmationText.message(forDeletingSelectionWith: store.deletionPlan(for: conversations)))
            case .project(let projectPath):
                Text(SessionDeletionConfirmationText.message(
                    forDeletingProjectAt: ProjectLocation(key: projectPath),
                    plan: store.deletionPlan(for: projectPath)
                ))
            case nil:
                EmptyView()
            }
        }
        .alert("Could not complete action", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.dismissError() } }
        )) {
            Button("OK") { store.dismissError() }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }
}
