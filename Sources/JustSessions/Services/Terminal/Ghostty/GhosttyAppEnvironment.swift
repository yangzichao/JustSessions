/// GhosttyTerminal sets `GHOSTTY_RESOURCES_DIR` in the app's own environment, for the shell integration of terminals
/// whose process Ghostty starts. The app starts its tabs' processes itself, and a CLI that inherited the variable would
/// take itself to run in Ghostty's own terminal app, as would every pane of the app's tmux server.
enum GhosttyAppEnvironment {
    static let variableNames = ["GHOSTTY_RESOURCES_DIR"]

    static func removingGhosttyVariables(from environment: [String: String]) -> [String: String] {
        var cleanedEnvironment = environment
        for name in variableNames {
            cleanedEnvironment[name] = nil
        }
        return cleanedEnvironment
    }
}
