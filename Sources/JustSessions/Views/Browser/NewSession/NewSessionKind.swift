import SwiftUI

/// What the New Session sheet opens: a CLI session, or a plain terminal, which runs no CLI and is no session.
enum NewSessionKind: Hashable {
    case cli(ConversationProvider)
    case plainTerminal

    /// The start button's fill: the CLI's hue, or for a terminal, which has none, a neutral graphite.
    var emphasisTintColor: Color {
        switch self {
        case .cli(let provider): provider.emphasisTintColor
        case .plainTerminal: .adaptive(light: 0x4A4A52, dark: 0x5C5C66)
        }
    }
}
