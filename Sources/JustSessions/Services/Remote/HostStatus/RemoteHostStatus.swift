import Foundation

struct RemoteHostStatus: Equatable, Sendable {
    let tmuxSessionNames: Set<String>
    let cliLocations: [ConversationProvider: RemoteCLILocation]?
    var tmuxServerProblem: String? = nil

    var installedProviders: Set<ConversationProvider>? {
        cliLocations.map { Set($0.keys) }
    }
}
