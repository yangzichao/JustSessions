import Combine
import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var aliases: [String: String]

    private let adapters: [any ConversationAdapter]
    private let launcher = TerminalLauncher()
    private let aliasesKey = "conversationAliases"

    init(adapters: [any ConversationAdapter] = [ClaudeAdapter(), CodexAdapter()]) {
        self.adapters = adapters
        self.aliases = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
    }

    func refresh() {
        guard !isLoading else { return }
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

    func launch(_ conversation: Conversation, action: ConversationAction) {
        guard let adapter = adapters.first(where: { $0.provider == conversation.provider }) else { return }
        do { try launcher.open(conversation, action: action, adapter: adapter) }
        catch { errorMessage = error.localizedDescription }
    }

    func dismissError() {
        errorMessage = nil
    }
}
