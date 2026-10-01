import Foundation

/// Finds which tools' CLIs are installed, so new sessions only offer those. SSH hosts answer in their refresh;
/// see `RemoteHostStatusProbe`.
enum InstalledCLIs {
    /// The tools whose CLI a launch on this Mac would find. The first lookup reads the login shell's PATH, so call
    /// this off the main actor.
    static func onThisMac(commandResolver: NativeCLICommandResolver) -> Set<ConversationProvider> {
        Set(ConversationProvider.allCases.filter { commandResolver.executablePath(named: $0.executableName) != nil })
    }
}
