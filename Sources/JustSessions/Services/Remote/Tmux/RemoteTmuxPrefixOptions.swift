import Foundation

enum RemoteTmuxPrefixOptions {
    /// `prefix2` too: a second prefix set in `~/.tmux.conf` would otherwise still take its key from the CLI.
    static let optionNames = ["prefix", "prefix2"]

    /// tmux `set-option` commands for the session `target` names, or without one for the session of the command
    /// they follow.
    static func setOptionCommands(usingHostPrefix: Bool, target: String? = nil) -> [String] {
        let targetArguments = target.map { " -t \($0)" } ?? ""
        return optionNames.map { name in
            usingHostPrefix ? "set-option\(targetArguments) -u \(name)" : "set-option\(targetArguments) \(name) None"
        }
    }
}
