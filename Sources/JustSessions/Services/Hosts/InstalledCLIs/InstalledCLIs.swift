import Foundation

enum InstalledCLIs {
    static func onThisMac(
        commandResolver: NativeCLICommandResolver,
        cancellation: ConversationDiscoveryCancellation
    ) throws -> Set<ConversationProvider> {
        var installed: Set<ConversationProvider> = []
        for provider in ConversationProvider.allCases {
            try cancellation.checkCancellation()
            if commandResolver.executablePath(named: provider.executableName) != nil { installed.insert(provider) }
        }
        return installed
    }
}
