import SwiftUI

extension ConversationProvider {
    /// Template images inherit the foreground color, including Kiro's custom ghost.
    func iconImage(size: CGFloat = 13) -> Image {
        switch self {
        case .claude: Image(systemName: "asterisk")
        case .codex: Image(systemName: "terminal")
        case .antigravity: Image(systemName: "sparkle")
        case .kiro: Image(nsImage: KiroGhostIcon.image(size: size))
        case .opencode: Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .pi: Image(systemName: "pi")
        }
    }
}
