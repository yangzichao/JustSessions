import AppKit
import SwiftUI

struct ContentView: View {
    /// Holds the window's store for the window's lifetime: `@StateObject` creates it once, where `@State`'s initial value
    /// would build a throwaway store every time the window's view is recreated. The holder never publishes; views follow
    /// the store's own observation.
    @StateObject private var storeHolder: StoreHolder
    private var store: ConversationStore { storeHolder.store }
    // periphery:ignore - the filters are read through their $ bindings, which Periphery does not see.
    @State private var searchText = ""
    // periphery:ignore
    @State private var recencyFilter: SessionRecencyFilter = .all
    // periphery:ignore
    @State private var providerFilter: ConversationProviderFilter = .all
    // periphery:ignore
    @State private var statusFilter: SessionStatusFilter = .all
    // periphery:ignore
    @State private var archiveFilter: SessionArchiveFilter = .hideArchived
    @State private var renamingConversation: Conversation?
    @State private var renamingProject: ProjectConversationGroup?
    @State private var renameDialogOpenCount = 0
    @State private var deletionRequest: SessionDeletionRequest?
    @State private var hasStartedScan = false

    init(readService: WorkspaceReadService) {
        _storeHolder = StateObject(wrappedValue: StoreHolder(store: ConversationStore(windowRegistry: .shared, readService: readService)))
    }

    var body: some View {
        ConversationBrowserView(
            store: store,
            searchText: $searchText,
            recencyFilter: $recencyFilter,
            providerFilter: $providerFilter,
            statusFilter: $statusFilter,
            archiveFilter: $archiveFilter,
            onRename: {
                renameDialogOpenCount += 1
                renamingConversation = $0
            },
            onRenameProject: {
                renameDialogOpenCount += 1
                renamingProject = $0
            },
            onRequestDeletion: { deletionRequest = $0 }
        )
        .onAppear {
            if !hasStartedScan {
                hasStartedScan = true
                store.reopenTabsFromLastQuit()
                for host in store.hosts { store.refresh(host) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            ExternalEditorStore.shared.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.prepareTabsForTermination()
        }
        .background(WorkspaceWindowRegistration(store: store))
        .onDisappear { store.closeWorkspace() }
        .modifier(
            RenameDialogs(
                store: store,
                conversation: $renamingConversation,
                project: $renamingProject,
                openCount: renameDialogOpenCount
            )
        )
        .sessionDeletionDialog(for: $deletionRequest, store: store)
        .storeAlert(store)
    }
}

private final class StoreHolder: ObservableObject {
    let store: ConversationStore

    init(store: ConversationStore) {
        self.store = store
    }
}
