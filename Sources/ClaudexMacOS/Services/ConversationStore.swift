import Combine
import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aliases: [String: String]
    @Published private(set) var terminalSessions: [TerminalSession] = []
    @Published private(set) var selectedTerminalID: UUID?
    @Published private(set) var deletingConversationID: String?

    private let adapters: [any ConversationAdapter]
    private let commandResolver = NativeCLICommandResolver()
    private let aliasesKey = "conversationAliases"

    init(adapters: [any ConversationAdapter] = [ClaudeAdapter(), CodexAdapter()]) {
        self.adapters = adapters
        self.aliases = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
    }

    func refresh() {
        guard !isLoading && deletingConversationID == nil else { return }
        isLoading = true
        errorMessage = nil
        let adapters = self.adapters
        Task.detached(priority: .userInitiated) {
            var found: [Conversation] = []
            var failures: [String] = []
            for adapter in adapters {
                do { found += try adapter.discover() }
                catch { failures.append("\(adapter.provider.rawValue): \(error.localizedDescription)") }
            }
            found.sort { $0.updatedAt > $1.updatedAt }
            await MainActor.run {
                self.conversations = found
                self.errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
                self.isLoading = false
            }
        }
    }

    func title(for conversation: Conversation) -> String {
        aliases[conversation.id] ?? conversation.suggestedTitle
    }

    func rename(_ conversation: Conversation, to proposedTitle: String) {
        let title = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || title == conversation.suggestedTitle {
            aliases.removeValue(forKey: conversation.id)
        } else {
            aliases[conversation.id] = title
        }
        UserDefaults.standard.set(aliases, forKey: aliasesKey)
    }

    func hasTerminal(for conversation: Conversation) -> Bool {
        terminalSessions.contains { $0.conversation.id == conversation.id }
    }

    func delete(_ conversation: Conversation) {
        guard !hasTerminal(for: conversation) else {
            errorMessage = ConversationDeletionError.activeTerminal.localizedDescription
            return
        }
        guard !isLoading, deletingConversationID == nil,
              let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { return }
        deletingConversationID = conversation.id
        Task.detached(priority: .userInitiated) {
            do {
                try adapter.delete(conversation)
                await MainActor.run {
                    self.conversations.removeAll { $0.id == conversation.id }
                    self.aliases.removeValue(forKey: conversation.id)
                    UserDefaults.standard.set(self.aliases, forKey: self.aliasesKey)
                    self.deletingConversationID = nil
                }
            } catch {
                await MainActor.run {
                    if !FileManager.default.fileExists(atPath: conversation.sourceFile.path) {
                        self.conversations.removeAll { $0.id == conversation.id }
                    }
                    self.errorMessage = error.localizedDescription
                    self.deletingConversationID = nil
                }
            }
        }
    }

    func launch(_ conversation: Conversation, action: ConversationAction) {
        if action == .resume,
           let runningSession = terminalSessions.first(where: {
               $0.action == .resume && $0.conversation.id == conversation.id && !$0.hasExited
           }) {
            selectedTerminalID = runningSession.id
            return
        }
        guard let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { return }
        do {
            let command = try commandResolver.resolve(conversation: conversation, action: action, adapter: adapter)
            let session = TerminalSession(
                conversation: conversation,
                action: action,
                displayTitle: title(for: conversation),
                command: command
            )
            terminalSessions.append(session)
            selectedTerminalID = session.id
        }
        catch { errorMessage = error.localizedDescription }
    }

    var selectedTerminal: TerminalSession? {
        terminalSessions.first { $0.id == selectedTerminalID }
    }

    func selectTerminal(_ id: UUID?) {
        selectedTerminalID = id
    }

    func closeTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        terminalSessions[index].close()
        terminalSessions.remove(at: index)
        if selectedTerminalID == id { selectedTerminalID = terminalSessions.last?.id }
    }

    func closeAllTerminals() {
        for session in terminalSessions { session.close() }
        terminalSessions = []
        selectedTerminalID = nil
    }

    func dismissError() {
        errorMessage = nil
    }
}
