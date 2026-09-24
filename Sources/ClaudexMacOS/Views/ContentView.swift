import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = ConversationStore()
    @State private var searchText = ""
    @State private var selection: ConversationBrowserSelection = .all
    @State private var providerFilter: ConversationProviderFilter = .all
    @State private var renamingConversation: Conversation?
    @State private var deletingConversation: Conversation?
    @State private var editedTitle = ""
    @State private var hasStartedScan = false

    var body: some View {
        ConversationBrowserView(
            store: store,
            searchText: $searchText,
            selection: $selection,
            providerFilter: $providerFilter,
            onRename: { conversation in
                editedTitle = store.title(for: conversation)
                renamingConversation = conversation
            },
            onDelete: { deletingConversation = $0 }
        )
        .onAppear {
            if !hasStartedScan {
                hasStartedScan = true
                store.refresh()
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
            Text("This changes the display name in claudex-macos.")
        }
        .confirmationDialog("Delete conversation?", isPresented: Binding(
            get: { deletingConversation != nil },
            set: { if !$0 { deletingConversation = nil } }
        )) {
            Button("Delete conversation", role: .destructive) {
                if let conversation = deletingConversation { store.delete(conversation) }
                deletingConversation = nil
            }
            Button("Cancel", role: .cancel) { deletingConversation = nil }
        } message: {
            if let conversation = deletingConversation {
                Text(conversation.provider == .codex
                    ? "Codex will permanently delete this session using its native CLI. This cannot be undone."
                    : "The Claude Code session file and its associated folder will move to the macOS Trash. This also removes its entry from Claude Code's local index.")
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
