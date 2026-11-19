import Foundation

struct RemoteTmuxPanes: Equatable, Sendable {
    struct Pane: Equatable, Sendable {
        let activityOption: String
        let title: String
    }

    let panesBySessionName: [String: Pane]

    static let endMarker = "justsessions-panes-listed"
    static let separator = " ~js~ "
    static let format = "#{session_name}\(separator)#{\(RemoteCLIActivityTitle.optionName)}\(separator)#{pane_title}"

    static func command(on host: String) -> String {
        let script =
            "command -v tmux >/dev/null 2>&1 || exit 0; tmux list-panes -a -F \(ShellQuoting.quoted(format)) 2>&1; echo \(endMarker)"
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    static func panes(inOutput output: String) -> RemoteTmuxPanes? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.contains(endMarker),
            RemoteHostTmuxFinding.unreachableServerMessage(in: output) == nil
        else { return nil }
        var panes: [String: Pane] = [:]
        for line in lines {
            let fields = line.components(separatedBy: separator)
            guard fields.count >= 3, fields[0].hasPrefix(TmuxSessionName.prefix) else { continue }
            if panes[fields[0]] == nil {
                panes[fields[0]] = Pane(activityOption: fields[1], title: fields[2...].joined(separator: separator))
            }
        }
        return RemoteTmuxPanes(panesBySessionName: panes)
    }

    func activity(of provider: ConversationProvider, inSession name: String) -> CLIActivity? {
        guard let pane = panesBySessionName[name] else { return nil }
        if RemoteCLIActivityTitle.providers.contains(provider) {
            guard !pane.activityOption.isEmpty else { return nil }
            return RemoteCLIActivityTitle.activity(inTerminalTitle: RemoteCLIActivityTitle.titlePrefix + pane.activityOption, of: provider)
        }
        return provider == .codex ? CodexTitleActivity.activity(inTerminalTitle: pane.title) : nil
    }
}
