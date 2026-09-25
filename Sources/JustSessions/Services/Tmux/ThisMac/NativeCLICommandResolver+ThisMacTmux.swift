import Foundation

extension NativeCLICommandResolver {
    /// The tmux installed on this Mac, whatever its version. It is looked up where the CLIs are.
    func installedTmuxServer() -> ThisMacTmuxServer? {
        executablePath(named: "tmux").map { ThisMacTmuxServer(executablePath: $0, environment: inheritedEnvironment) }
    }

    /// The tmux new tabs run their CLI in: installed and known to be new enough. A refresh of this Mac checks the
    /// version the first time, so until then tabs run the CLI directly.
    func thisMacTmuxServer() -> ThisMacTmuxServer? {
        installedTmuxServer().flatMap { $0.isKnownToHaveSupportedVersion ? $0 : nil }
    }
}
