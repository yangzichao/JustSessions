import SwiftUI

struct SessionMoveToFolderMenu: View {
    let store: ConversationStore
    let conversation: Conversation

    var body: some View {
        if conversation.provider.movesSessionsToOtherFolders && !conversation.isSubagent {
            let destinations = store.moveDestinations(for: conversation)
            Menu {
                ForEach(destinations) { destination in
                    Button {
                        store.moveSession(conversation, toFolder: destination.folderPath)
                    } label: {
                        Text(verbatim: destination.menuTitle)
                    }
                }
                if conversation.host == .thisMac {
                    if !destinations.isEmpty { Divider() }
                    Button("Choose folder…", action: chooseFolder)
                }
            } label: {
                Label("Move to", systemImage: "folder")
            }
            .disabled(!store.canMoveSession(conversation) || (destinations.isEmpty && conversation.host != .thisMac))
        }
    }

    private func chooseFolder() {
        let store = store
        let conversation = conversation
        let parentFolder = URL(fileURLWithPath: conversation.projectPath).deletingLastPathComponent().path
        ProjectFolderPanel.choose(prompt: AppLocalization.string("Move here"), startingAt: parentFolder) { folder in
            store.moveSession(conversation, toFolder: folder)
        }
    }
}
