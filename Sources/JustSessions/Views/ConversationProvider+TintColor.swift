import SwiftUI

extension ConversationProvider {
    var tintColor: Color {
        switch self {
        case .claude: .orange
        case .codex: .blue
        case .antigravity: .purple
        }
    }
}
