import Foundation
@testable import JustSessions

/// Each tool's adapter, reading from a folder that does not exist, for tests of the arguments it starts its CLI with.
func adapterWithoutSessions(for provider: ConversationProvider) -> any ConversationAdapter {
    let unusedDirectory = URL(fileURLWithPath: "/nonexistent/justsessions-tests")
    return switch provider {
    case .claude: ClaudeAdapter(configurationDirectory: unusedDirectory)
    case .codex: CodexAdapter(codexDirectory: unusedDirectory)
    case .antigravity: AntigravityAdapter(configurationDirectory: unusedDirectory)
    case .kiro: KiroAdapter(sessionsDirectory: unusedDirectory)
    case .opencode: OpenCodeAdapter(databaseFile: unusedDirectory.appendingPathComponent("opencode.db"))
    case .pi: PiAdapter(sessionsDirectory: unusedDirectory)
    }
}
