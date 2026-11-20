import Foundation

extension ConversationProvider {
    var storesSessionsInSQLite: Bool {
        switch self {
        case .antigravity, .opencode: true
        case .claude, .codex, .kiro, .pi: false
        }
    }
}
