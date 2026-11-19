import SwiftUI

extension ConversationProvider {
    var tintColor: Color {
        .adaptive(tintHexColor)
    }

    var textColor: ThemeColor {
        ThemeColor(role: .providerText(self))
    }

    var emphasisTintColor: Color {
        switch self {
        case .claude: .adaptive(light: 0xE0700F, dark: 0xD9691A)
        case .codex: .adaptive(light: 0x2F6BFF, dark: 0x3A6DF0)
        case .antigravity: .adaptive(light: 0x9A3FE6, dark: 0x9447E0)
        case .kiro: .adaptive(light: 0xC92F78, dark: 0xC4386F)
        case .opencode: .adaptive(light: 0x0E8072, dark: 0x14857A)
        case .pi: .adaptive(light: 0x2F8424, dark: 0x358A2A)
        }
    }
}
