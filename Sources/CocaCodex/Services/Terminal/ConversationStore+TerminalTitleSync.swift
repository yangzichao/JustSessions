import Foundation

extension ConversationStore {
    func synchronizeTerminalTitles() {
        let conversationsByID = conversations.reduce(into: [String: Conversation]()) {
            $0[$1.id] = $1
        }
        for session in terminalSessions {
            if let conversation = session.conversation,
               let current = conversationsByID[conversation.id] {
                session.synchronize(conversation: current, displayTitle: title(for: current))
            }
        }
    }

    func associateOpenCodexSessions() {
        let processes = terminalSessions.compactMap { session -> (UUID, Int32)? in
            guard session.provider == .codex && session.action == .new && session.conversation == nil,
                  session.processID > 0 else { return nil }
            return (session.id, session.processID)
        }
        guard !processes.isEmpty else { return }

        Task.detached(priority: .utility) {
            let locator = CodexSessionFileLocator()
            let openFiles = processes.compactMap { sessionID, processID -> (UUID, Int32, String)? in
                guard let file = locator.openSessionFile(for: processID) else { return nil }
                return (sessionID, processID, file.path)
            }
            await MainActor.run {
                let conversationsByFile = self.conversations.reduce(into: [String: Conversation]()) {
                    $0[$1.sourceFile.standardizedFileURL.path] = $1
                }
                for (sessionID, processID, filePath) in openFiles {
                    guard let session = self.terminalSessions.first(where: { $0.id == sessionID }),
                          session.processID == processID,
                          let conversation = conversationsByFile[filePath],
                          conversation.provider == session.provider,
                          conversation.projectDirectoryKey == session.projectDirectoryKey else { continue }
                    session.synchronize(conversation: conversation, displayTitle: self.title(for: conversation))
                }
            }
        }
    }
}
