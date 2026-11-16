import Dispatch
@testable import JustSessions

/// A tmux session's history whose tmux answers each search step with the next of `countOutputs`, and each other
/// command with nothing. It records every command it was given; `holdsFirstCommand` keeps the first one waiting until
/// `releaseFirstCommand()`, as a slow SSH host would.
final class ScriptedTmuxHistory: @unchecked Sendable {
    let sessionName = "justsessions-terminal-a1b2c3d4"
    private let countOutputs: LockedValue<[String?]>
    private let recordedCommands = LockedValue<[[String]]>([])
    private let firstCommandRelease = DispatchSemaphore(value: 0)
    private let holdsFirstCommand: Bool

    init(countOutputs: [String?], holdsFirstCommand: Bool = false) {
        self.countOutputs = LockedValue(countOutputs)
        self.holdsFirstCommand = holdsFirstCommand
    }

    var commands: [[String]] { recordedCommands.value }

    /// The text each search step looked for, in the order tmux ran them.
    var searchedTexts: [String] {
        commands.compactMap { command in
            command.firstIndex(of: "search-backward-text").map { command[$0 + 1] }
        }
    }

    var history: TmuxHistory {
        TmuxHistory(sessionName: sessionName) { [self] arguments in answer(arguments) }
    }

    func releaseFirstCommand() {
        firstCommandRelease.signal()
    }

    /// A count line as tmux prints it, with nothing for a count it didn't keep. `foundAny` is whether the search found
    /// any, by default whether it counted any.
    static func countLine(_ total: Int?, partial: Bool = false, foundAny: Bool? = nil) -> String {
        let found = (foundAny ?? total.map { $0 > 0 }).map { $0 ? "1" : "0" } ?? ""
        return "\(TmuxHistorySearchCommands.countMarker) \(total.map(String.init) ?? "") \(total == nil ? "" : partial ? "1" : "0") \(found)\n"
    }

    private func answer(_ arguments: [String]) -> String? {
        var isFirstCommand = false
        recordedCommands.update {
            isFirstCommand = $0.isEmpty
            $0.append(arguments)
        }
        if isFirstCommand && holdsFirstCommand {
            _ = firstCommandRelease.wait(timeout: .now() + 30)
        }
        guard arguments.contains("display-message") else { return "" }
        var output: String?
        countOutputs.update { outputs in
            output = outputs.isEmpty ? nil : outputs.removeFirst()
        }
        return output
    }
}
