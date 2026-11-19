import Foundation

/// Pi and OpenCode on an SSH host tell what they do through the extensions they report with on this Mac (see
/// `LiveSessionReporting`), which there set it in the title of the tab's tmux session (`LiveSessionTmuxActivity`). So
/// a Pi or OpenCode tab's tmux session first writes the extension to the host's `folder`, and then starts the CLI with
/// it, as on this Mac: Pi with `--extension`, OpenCode with a TUI configuration that loads the plugin beside it. When
/// the files can't be written, as in a home folder that can't be written to, the CLI starts without them, as Pi would
/// refuse to start with an extension that isn't there.
enum RemoteLiveSessionReporting {
    static let folder = ".cache/justsessions/live-session-reporting"

    static func files(for provider: ConversationProvider) -> [(name: String, contents: String)]? {
        switch provider {
        case .pi:
            return [(PiLiveSessionExtension.fileName, PiLiveSessionExtension.source)]
        case .opencode:
            // OpenCode finds a plugin named by a relative path beside the configuration that names it.
            return [
                (OpenCodeLiveSessionPlugin.fileName, OpenCodeLiveSessionPlugin.source),
                ("tui.json", #"{"plugin":["./\#(OpenCodeLiveSessionPlugin.fileName)"]}"# + "\n"),
            ]
        case .claude, .codex, .antigravity, .kiro:
            return nil
        }
    }

    static func quotedArguments(for provider: ConversationProvider) -> [String] {
        provider == .pi ? ["--extension", hostPath(of: PiLiveSessionExtension.fileName, for: provider)] : []
    }

    static func environment(for provider: ConversationProvider) -> [String] {
        let option = "\(LiveSessionTmuxActivity.optionVariable)=\(ShellQuoting.quoted(RemoteCLIActivityTitle.optionName))"
        guard provider == .opencode else { return [option] }
        return [option, "\(OpenCodeLiveSessionPlugin.tuiConfigurationVariable)=\(hostPath(of: "tui.json", for: provider))"]
    }

    static func command(for provider: ConversationProvider, reporting: String, otherwise: String) -> String {
        let arguments =
            [reporting, otherwise, provider.executableName]
            + (files(for: provider) ?? []).flatMap { [$0.name, $0.contents] }
        return "exec sh -c \(ShellQuoting.quoted(script)) sh " + arguments.map(ShellQuoting.quoted).joined(separator: " ")
    }

    static let script = """
        reporting=$1 otherwise=$2 folder=$HOME/\(folder)/$3
        shift 3
        mkdir -p "$folder" 2>/dev/null || eval "$otherwise"
        while [ $# -gt 1 ]; do
          { printf '%s' "$2" > "$folder/$1.$$" && mv -f "$folder/$1.$$" "$folder/$1"; } 2>/dev/null || {
            rm -f "$folder/$1.$$"
            eval "$otherwise"
          }
          shift 2
        done
        eval "$reporting"
        """

    private static func hostPath(of fileName: String, for provider: ConversationProvider) -> String {
        "\"$HOME\"/\(folder)/\(provider.executableName)/\(fileName)"
    }
}
