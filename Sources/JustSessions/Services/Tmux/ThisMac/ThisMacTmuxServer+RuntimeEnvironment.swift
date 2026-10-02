import Foundation

extension ThisMacTmuxServer {
    /// Keep the bundled terminal database available to the tmux client, server, and the CLIs inside its panes.
    func runtimeEnvironment(from original: [String: String]) -> [String: String] {
        guard let terminfoDirectory else { return original }
        var result = original
        let inheritedDirectories = original["TERMINFO_DIRS"].map { [$0] } ?? []
        result["TERMINFO_DIRS"] = ([terminfoDirectory] + inheritedDirectories + ["/usr/share/terminfo"]).joined(separator: ":")
        return result
    }
}
