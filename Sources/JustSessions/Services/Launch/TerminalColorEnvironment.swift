import Foundation

enum TerminalColorEnvironment {
    private static let variablesThatAlwaysDisableColor = ["NO_COLOR", "NODE_DISABLE_COLORS"]
    private static let variablesThatDisableColorWhenFalse = ["CLICOLOR", "FORCE_COLOR"]
    private static let falseValues: Set<String> = ["0", "false"]

    static func removingColorDisablingVariables(from environment: [String: String]) -> [String: String] {
        var cleanedEnvironment = environment
        for name in variablesThatAlwaysDisableColor {
            cleanedEnvironment[name] = nil
        }
        for name in variablesThatDisableColorWhenFalse {
            if let value = cleanedEnvironment[name], falseValues.contains(value.lowercased()) {
                cleanedEnvironment[name] = nil
            }
        }
        return cleanedEnvironment
    }

    static func embeddedTerminalEnvironment(from inheritedEnvironment: [String: String]) -> [String: String] {
        var environment = ClaudeCodeSessionEnvironment.removingSessionVariables(
            from: GhosttyAppEnvironment.removingGhosttyVariables(from: removingColorDisablingVariables(from: inheritedEnvironment))
        )
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        if environment["LANG"] == nil { environment["LANG"] = "en_US.UTF-8" }
        return environment
    }
}
