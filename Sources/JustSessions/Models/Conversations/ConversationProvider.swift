import Foundation

enum ConversationProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex"
    case antigravity = "Antigravity"
    case kiro = "Kiro CLI"
    case opencode = "OpenCode"
    case pi = "Pi"

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "terminal"
        case .antigravity: "sparkle"
        case .kiro: "bolt"
        case .opencode: "chevron.left.forwardslash.chevron.right"
        case .pi: "pi"
        }
    }

    /// The CLI's command name, on this Mac and on SSH hosts.
    var executableName: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .antigravity: "agy"
        case .kiro: "kiro-cli"
        case .opencode: "opencode"
        case .pi: "pi"
        }
    }

    /// A new session's tab title until the tab is linked to the session its CLI saves.
    var newSessionTabTitle: String { "New \(rawValue) session" }

    var supportsBranchFromLauncher: Bool {
        switch self {
        case .claude, .codex, .opencode, .pi: true
        case .antigravity, .kiro: false
        }
    }

    var supportsDeletionFromLauncher: Bool {
        switch self {
        case .claude, .codex, .antigravity, .kiro, .pi: true
        case .opencode: false
        }
    }

    /// Tools whose sessions are listed and resumed on SSH hosts.
    var supportsRemoteHosts: Bool {
        switch self {
        case .claude, .codex, .antigravity, .kiro: true
        case .opencode, .pi: false
        }
    }

    /// Whether a new session's tab on this Mac is linked to the first session that appears in its project after it
    /// started, as on SSH hosts. The other tools leave evidence of the session a process writes; see
    /// `NewSessionFileFinder`. These write their sessions without keeping the file open, or into a database that
    /// every session shares.
    var linksNewSessionsByAppearance: Bool {
        switch self {
        case .claude, .codex, .antigravity: false
        case .kiro, .opencode, .pi: true
        }
    }

    func runs(on host: SessionHost) -> Bool {
        host == .thisMac || supportsRemoteHosts
    }

    /// Session ids end up in file names, tmux session names, and shell commands, so only the tool's own id
    /// format is accepted. OpenCode ids look like `ses_` and letters and digits; the other tools use UUIDs.
    func isValidSessionID(_ value: String) -> Bool {
        switch self {
        case .opencode:
            guard value.hasPrefix("ses_") else { return false }
            let suffix = value.dropFirst("ses_".count)
            return (8...64).contains(suffix.count) && suffix.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        case .claude, .codex, .antigravity, .kiro, .pi:
            return ConversationMetadata.isValidSessionID(value)
        }
    }
}
