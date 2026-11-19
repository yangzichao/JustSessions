import Foundation

extension ThisMacTmuxServer {
    func runtimeEnvironment(from original: [String: String]) -> [String: String] {
        var result = GhosttyAppEnvironment.removingGhosttyVariables(from: original)
        guard let terminfoDirectory else { return result }
        let inheritedDirectories = original["TERMINFO_DIRS"].map { [$0] } ?? []
        result["TERMINFO_DIRS"] = ([terminfoDirectory] + inheritedDirectories + ["/usr/share/terminfo"]).joined(separator: ":")
        return result
    }
}
