import Foundation

struct RemoteHostCheckProgram: Equatable, Sendable {
    let provider: ConversationProvider
    let program: String
    let asksVersion: Bool
    var location: RemoteCLILocation? = nil

    var key: String { "cli-" + provider.executableName }

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

    func located(by cliLocations: [ConversationProvider: RemoteCLILocation]) -> RemoteHostCheckProgram {
        guard asksVersion, let location = cliLocations[provider] else { return self }
        if case .installed(let path) = location {
            guard RemoteHostCheckScript.doubleQuoted(path) != nil else { return self }
            return RemoteHostCheckProgram(provider: provider, program: path, asksVersion: true, location: location)
        }
        return RemoteHostCheckProgram(provider: provider, program: program, asksVersion: true, location: location)
    }
}
