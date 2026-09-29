import Foundation

enum ConversationProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex"
    case antigravity = "Antigravity"

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "terminal"
        case .antigravity: "sparkle"
        }
    }

    /// The CLI's command name, on this Mac and on SSH hosts.
    var executableName: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .antigravity: "agy"
        }
    }

    var supportsBranchFromLauncher: Bool { self != .antigravity }
    var supportsDeletionFromLauncher: Bool { self != .antigravity }
    /// Tools whose sessions are listed and resumed on SSH hosts.
    var supportsRemoteHosts: Bool { self != .antigravity }

    func runs(on host: SessionHost) -> Bool {
        host == .thisMac || supportsRemoteHosts
    }
}
