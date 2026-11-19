import Foundation

struct RemoteHostCheckContext: Sendable {
    let host: String
    let shellStartup: RemoteShellStartup
    let programs: [RemoteHostCheckProgram]
    let session: HostCheckSession?
    let providersWithSessions: Set<ConversationProvider>
}
