import Foundation

/// Shows a name a CLI appends to a file as soon as it does, instead of at the next refresh: a name chosen with
/// `/rename` in Claude Code or `/name` in Pi, or a name Codex gives a thread. For Claude Code this backs up its live
/// registry, which `synchronizeClaudeLiveNames` reads but which some setups leave without the name. Only tabs on
/// this Mac; see `AppendedSessionNameSource`.
extension ConversationStore {
    func startAppendedSessionNameFollowing(
        interval: Duration = .seconds(1),
        codexDirectory: URL = CodexAdapter.defaultCodexDirectory
    ) {
        let readers = AppendedSessionNameReaders()
        runPeriodically(every: interval) { await $0.followAppendedSessionNames(readers: readers, codexDirectory: codexDirectory) }
    }

    func followAppendedSessionNames(readers: AppendedSessionNameReaders, codexDirectory: URL) async {
        guard !isTearingDownWorkspace else { return }
        let lookups = terminalSessions.compactMap { tab -> AppendedSessionNameReaders.Lookup? in
            guard tab.host == .thisMac, tab.isRunning else { return nil }
            guard let conversation = tab.conversation,
                  let file = AppendedSessionNameSource.file(for: conversation, codexDirectory: codexDirectory) else { return nil }
            return AppendedSessionNameReaders.Lookup(tabID: tab.id, conversation: conversation, file: file)
        }
        let names = await Task.detached(priority: .utility) { await readers.names(for: lookups) }.value
        guard !isTearingDownWorkspace else { return }
        let tabsByID = Dictionary(uniqueKeysWithValues: terminalSessions.map { ($0.id, $0) })
        for name in names {
            let lookup = name.lookup
            guard let tab = tabsByID[lookup.tabID], tab.isRunning,
                  let conversation = tab.conversation, conversation.id == lookup.conversation.id,
                  AppendedSessionNameSource.file(for: conversation, codexDirectory: codexDirectory) == lookup.file else { continue }
            applyChosenName(name.value, toSessionID: conversation.sessionID, provider: conversation.provider, shownIn: tab)
        }
    }
}
