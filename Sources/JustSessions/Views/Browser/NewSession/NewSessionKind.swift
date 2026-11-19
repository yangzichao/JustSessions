import SwiftUI

enum NewSessionKind: Hashable {
    case cli(ConversationProvider)
    case plainTerminal

    var emphasisTintColor: Color {
        switch self {
        case .cli(let provider): provider.emphasisTintColor
        case .plainTerminal: .adaptive(light: 0x4A4A52, dark: 0x5C5C66)
        }
    }
}
