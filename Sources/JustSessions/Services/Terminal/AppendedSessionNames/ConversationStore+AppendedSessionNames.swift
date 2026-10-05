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
        runPeriodically(every: interval) { $0.followAppendedSessionNames(readers: readers, codexDirectory: codexDirectory) }
    }

    func followAppendedSessionNames(readers: AppendedSessionNameReaders, codexDirectory: URL) {
        var tabsByFile: [URL: [(tab: TerminalSession, conversation: Conversation)]] = [:]
        for tab in terminalSessions where tab.host == .thisMac && tab.isRunning {
            guard let conversation = tab.conversation,
                  let file = AppendedSessionNameSource.file(for: conversation, codexDirectory: codexDirectory) else { continue }
            tabsByFile[file, default: []].append((tab, conversation))
        }
        readers.keepOnly(Set(tabsByFile.keys))
        for (file, tabs) in tabsByFile {
            let lines = readers.newLines(in: file)
            guard !lines.isEmpty else { continue }
            for (tab, conversation) in tabs {
                guard let name = AppendedSessionNameSource.latestName(for: conversation, amongLines: lines) else { continue }
                applyChosenName(name, toSessionID: conversation.sessionID, provider: conversation.provider, shownIn: tab)
            }
        }
    }
}
