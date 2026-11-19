import Foundation

/// What a start command of your own stands in for, see `CLIStartCommands`. For most tools it is the executable, whose
/// options come straight after it. Kiro CLI's options belong to its `chat` subcommand, as in
/// `kiro-cli chat --trust-all-tools`, so its start command stands in for `kiro-cli chat`.
extension ConversationProvider {
    var defaultStartCommand: String {
        defaultStartCommandWords.joined(separator: " ")
    }

    private var defaultStartCommandWords: [String] {
        self == .kiro ? [executableName, "chat"] : [executableName]
    }

    func argumentsAfterCustomStartCommand(_ arguments: [String]) -> [String] {
        let subcommand = defaultStartCommandWords.dropFirst()
        return arguments.starts(with: subcommand) ? Array(arguments.dropFirst(subcommand.count)) : arguments
    }
}
