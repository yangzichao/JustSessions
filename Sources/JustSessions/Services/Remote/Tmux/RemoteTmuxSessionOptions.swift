import Foundation

/// The tmux commands a remote tab's session runs on every attach, after `new-session -A`; see `RemoteTmuxAttachScript`.
/// The agent that fixes what a host check found is told them too; see `HostFixAgentHostFacts`.
enum RemoteTmuxSessionOptions {
    // The status line and mouse settings make it look and scroll like the CLI on its own, and with no prefix key
    // Ctrl-B reaches the CLI, unless the host uses its own; see `RemoteTmuxPrefixOptions`. `set-titles` passes the
    // title the CLI gives its pane (`#T`) on to the tab, where Codex says what it is doing; Claude Code's, Kiro CLI's,
    // and Antigravity's relays, and Pi's and OpenCode's extensions, put what they do in front of it
    // (`RemoteCLIActivityTitle`). It comes before `mouse`, which tmux before 2.1 rejects along with every option after
    // it. Passthrough lets a CLI's copy reach this Mac's clipboard: OpenCode sends OSC 52 wrapped for tmux, which tmux
    // 3.3 and later drop with it off, and its unwrapped OSC 52 only with the server-wide `set-clipboard on`. Older tmux
    // always passes it, and `-q` skips the option there. These are options of this session and its window only; the
    // host's other tmux sessions keep theirs. The exceptions are three server options. `escape-time`: tmux before 3.5,
    // such as Ubuntu 24.04's 3.4, waits 500 ms after Esc to see whether a longer key sequence follows, so Esc reached
    // the CLI half a second late. The host's other sessions get 10 ms too, as tmux 3.5 and later give them anyway.
    // `extended-keys`: the tab sends Shift-Return and Control keys as CSI u (`ShiftReturnKey`, `TerminalControlKey`),
    // as it does to this Mac's tmux. tmux 3.4 passes them on to a CLI that asks for modifyOtherKeys, as Claude Code,
    // Codex, Pi, and OpenCode do, with no option set; tmux 3.5 and later give that CLI a plain Return instead unless
    // `extended-keys` is on, and then pass the keys on in `extended-keys-format`, set to CSI u as on this Mac. `-q`
    // skips both on a tmux without them: before 3.2, and 3.4 has only the CSI u format. `on`, not `always`: a shell or
    // editor in the host's other sessions, which doesn't ask, keeps each key's plain byte. `focus-events`: tmux asks the
    // tab to say when it gains and loses the keyboard, and tells a CLI that asks, as this Mac's tmux does. Claude Code
    // tracks focus, and without it shows a hint to set the option. A program in the host's other sessions hears of it
    // only when it asks.
    static func setOptionCommands(for provider: ConversationProvider, usingHostPrefix: Bool) -> [String] {
        let titleFormat = provider == .claude ? RemoteClaudeSessionTitle.titleFormat
            : RemoteCLIActivityTitle.providers.contains(provider) ? RemoteCLIActivityTitle.titleFormat : "#T"
        return [
            "set-option status off", "set-option set-titles on", "set-option set-titles-string '\(titleFormat)'",
            "set-option mouse on", "set-option -wq allow-passthrough on", "set-option -s escape-time 10",
            "set-option -sq extended-keys on", "set-option -sq extended-keys-format csi-u",
            "set-option -sq focus-events on",
        ]
            + RemoteTmuxPrefixOptions.setOptionCommands(usingHostPrefix: usingHostPrefix)
    }
}
