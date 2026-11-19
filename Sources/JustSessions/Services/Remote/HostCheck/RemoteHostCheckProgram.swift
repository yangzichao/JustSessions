import Foundation

struct RemoteHostCheckProgram: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case cliExecutable
        case customStartCommand
    }

    let provider: ConversationProvider
    let program: String
    let source: Source
    var location: RemoteCLILocation? = nil

    var key: String { HostCheckFindingID.cli(provider).rawValue }

    static func all(startCommands: (ConversationProvider) -> String?) -> [RemoteHostCheckProgram] {
        ConversationProvider.allCases.compactMap { provider in
            guard let startCommand = CLIStartCommandLine.customCommand(startCommands(provider)) else {
                return RemoteHostCheckProgram(provider: provider, program: provider.executableName, source: .cliExecutable)
            }
            guard case .program(let program) = StartCommandShape(startCommand),
                RemoteHostCheckScript.doubleQuoted(program) != nil
            else { return nil }
            return RemoteHostCheckProgram(provider: provider, program: program, source: .customStartCommand)
        }
    }

    func located(by cliLocations: [ConversationProvider: RemoteCLILocation]) -> RemoteHostCheckProgram {
        guard source == .cliExecutable, let location = cliLocations[provider] else { return self }
        if case .installed(let path) = location {
            guard RemoteHostCheckScript.doubleQuoted(path) != nil else { return self }
            return RemoteHostCheckProgram(provider: provider, program: path, source: .cliExecutable, location: location)
        }
        return RemoteHostCheckProgram(provider: provider, program: program, source: .cliExecutable, location: location)
    }
}
