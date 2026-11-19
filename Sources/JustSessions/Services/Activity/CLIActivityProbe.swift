import Foundation

struct CLIActivityProbe: Sendable {
    let provider: ConversationProvider
    let processID: Int32
    let sessionFile: URL?
    var sessionID: String? = nil
    var terminalTitle: String? = nil
}

extension TerminalSession {
    var cliActivityProbe: CLIActivityProbe? {
        guard let provider else { return nil }
        guard host == .thisMac else {
            guard provider == .codex || RemoteCLIActivityTitle.providers.contains(provider) else { return nil }
            return CLIActivityProbe(provider: provider, processID: 0, sessionFile: nil, terminalTitle: terminalTitle)
        }
        return CLIActivityProbe(
            provider: provider,
            processID: cliProcessID,
            sessionFile: conversation?.sourceFile,
            sessionID: conversation?.sessionID,
            terminalTitle: terminalTitle
        )
    }
}
