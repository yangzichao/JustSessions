import Foundation

/// A tool's CLI as Check this host… looks for it on the host: the program the tool starts with there.
struct RemoteHostCheckProgram: Equatable, Sendable {
    let provider: ConversationProvider
    /// The tool's executable, its path in an install folder, or the program of your start command for the tool on
    /// the host.
    let program: String
    /// Only the executable the app starts by itself is asked for `--version`; a start command of your own may run a
    /// script that does something else with it.
    let asksVersion: Bool
    /// Where the host's CLI lookup found the tool's executable, which tabs start it from; nil for your start
    /// command's program, and for an executable the lookup didn't find.
    var location: RemoteCLILocation? = nil

    /// The output key of its lookup; see `RemoteHostCheckScript`.
    var key: String { "cli-" + provider.executableName }

    /// One for each tool, with your start command's program in place of the executable where you set one. A tool
    /// whose start command names its program only when it runs, such as through a variable, is left out: looking up
    /// the executable instead would check something the tool doesn't start with. So is a program whose name the
    /// check can't quote; see `RemoteHostCheckScript.doubleQuoted(_:)`.
    static func all(startCommands: (ConversationProvider) -> String?) -> [RemoteHostCheckProgram] {
        ConversationProvider.allCases.compactMap { provider in
            guard let startCommand = CLIStartCommandLine.customCommand(startCommands(provider)) else {
                return RemoteHostCheckProgram(provider: provider, program: provider.executableName, asksVersion: true)
            }
            guard case .program(let program) = StartCommandShape(startCommand),
                RemoteHostCheckScript.doubleQuoted(program) != nil
            else { return nil }
            return RemoteHostCheckProgram(provider: provider, program: program, asksVersion: false)
        }
    }

    /// The tool's executable where the host's CLI lookup found it, so the check looks where a tab starts it from: at
    /// its path, when only an install folder has it. A start command's program stays as it is.
    func located(by cliLocations: [ConversationProvider: RemoteCLILocation]) -> RemoteHostCheckProgram {
        guard asksVersion, let location = cliLocations[provider] else { return self }
        if case .installed(let path) = location {
            guard RemoteHostCheckScript.doubleQuoted(path) != nil else { return self }
            return RemoteHostCheckProgram(provider: provider, program: path, asksVersion: true, location: location)
        }
        return RemoteHostCheckProgram(provider: provider, program: program, asksVersion: true, location: location)
    }
}
