import Foundation

/// Pi and OpenCode on an SSH host tell what they do through the extensions they report with on this Mac (see
/// `LiveSessionReporting`), which there set it in the title of the tab's tmux session (`LiveSessionTmuxActivity`). So
/// a Pi or OpenCode tab's tmux session first writes the extension to the host's `folder`, and then starts the CLI with
/// it, as on this Mac: Pi with `--extension`, OpenCode with a TUI configuration that loads the plugin beside it. When
/// the files can't be written, as in a home folder that can't be written to, the CLI starts without them, as Pi would
/// refuse to start with an extension that isn't there.
///
/// A TUI configuration of the user's own that the host's startup files name in `OPENCODE_TUI_CONFIG` stays in place,
/// as those files set it after the tab's command does, and that OpenCode shows no activity.
enum RemoteLiveSessionReporting {
    /// Relative to the home folder on the host.
    static let folder = ".cache/justsessions/live-session-reporting"

    /// The extension's files, by name in the folder in `folder` named after the tool's command; nil for a tool without
    /// an extension.
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

    /// The CLI's arguments for the extension, as words for the login shell, which may be fish.
    static func quotedArguments(for provider: ConversationProvider) -> [String] {
        provider == .pi ? ["--extension", hostPath(of: PiLiveSessionExtension.fileName, for: provider)] : []
    }

    /// What the login shell that starts the CLI sets, as `NAME=value` words for `sh`.
    static func environment(for provider: ConversationProvider) -> [String] {
        let option = "\(LiveSessionTmuxActivity.optionVariable)=\(ShellQuoting.quoted(RemoteCLIActivityTitle.optionName))"
        guard provider == .opencode else { return [option] }
        return [option, "\(OpenCodeLiveSessionPlugin.tuiConfigurationVariable)=\(hostPath(of: "tui.json", for: provider))"]
    }

    /// For the pane's shell, which may be fish: `exec sh -c <script> …`, which writes the provider's files and then
    /// runs `reporting`, or `otherwise` when they could not be written. Both are commands for `sh`, which runs one in
    /// its place. Each file is written beside its place and then moved there, so a CLI that loads it never reads half
    /// of it. A failure says nothing in the tab, as the CLI then starts as before.
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

    /// The file's path on the host, as a word for any of the shells: `"$HOME"/<folder>/<command name>/<name>`.
    private static func hostPath(of fileName: String, for provider: ConversationProvider) -> String {
        "\"$HOME\"/\(folder)/\(provider.executableName)/\(fileName)"
    }
}
