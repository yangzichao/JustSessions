import Foundation

/// What a Codex CLI is doing, as the terminal title it gives itself with `CodexThreadTitle.launchArguments` says. Its
/// first item is the run state, after a spinner frame while a turn is under way: `Ready` between turns, and `Working`,
/// `Thinking`, `Waiting` (for a background terminal), `Starting`, or, before 0.131, `Undoing` during one. While
/// Codex 0.128 or later waits for your approval or answer, the title starts `[ ! ] Action Required` instead,
/// alternating each second with `[ . ] Action Required`. Items are joined with ` | `, and `●` comes first while Codex
/// listens to the microphone; see codex-rs `tui/src/chatwidget/status_surfaces.rs`.
enum CodexTitleActivity {
    static let actionRequired = "Action Required"
    private static let workingStates: Set<Substring> = ["Working", "Thinking", "Waiting", "Starting", "Undoing"]

    /// Nil for a title with no run state, as from Codex before 0.124 or before it first titles its terminal.
    static func activity(inTerminalTitle title: String) -> CLIActivity? {
        guard let firstItem = title.components(separatedBy: " | ").first?.trimmingCharacters(in: .whitespaces),
            !firstItem.isEmpty
        else { return nil }
        if firstItem.hasSuffix(actionRequired) { return .needsInput(reason: nil) }
        // The spinner frame and `●`, when shown, come before the run state.
        guard let runState = firstItem.split(whereSeparator: \.isWhitespace).last else { return nil }
        if runState == "Ready" { return .idle }
        return workingStates.contains(runState) ? .working : nil
    }
}
