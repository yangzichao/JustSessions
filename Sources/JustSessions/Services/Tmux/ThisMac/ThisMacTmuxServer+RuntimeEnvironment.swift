import Foundation

extension ThisMacTmuxServer {
    /// Keep the bundled terminal database available to the tmux client, server, and the CLIs inside its panes, and
    /// Ghostty's variables out of them; see `GhosttyAppEnvironment`.
    func runtimeEnvironment(from original: [String: String]) -> [String: String] {
        var result = GhosttyAppEnvironment.removingGhosttyVariables(from: original)
        guard let terminfoDirectory else { return result }
        let inheritedDirectories = original["TERMINFO_DIRS"].map { [$0] } ?? []
        result["TERMINFO_DIRS"] = ([terminfoDirectory] + inheritedDirectories + ["/usr/share/terminfo"]).joined(separator: ":")
        return result
    }
}
