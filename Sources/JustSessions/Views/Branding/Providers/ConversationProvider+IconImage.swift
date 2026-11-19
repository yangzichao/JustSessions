import SwiftUI

extension ConversationProvider {
    func iconImage(size: CGFloat = 13) -> Image {
        switch self {
        case .claude: Image(systemName: "asterisk")
        case .codex: Image(nsImage: CodexPromptHexagonIcon.image(size: size))
        case .antigravity: Image(systemName: "sparkle")
        case .kiro: Image(nsImage: KiroGhostIcon.image(size: size))
        case .opencode: Image(nsImage: OpenCodeBlockRingIcon.image(size: size))
        case .pi: Image(systemName: "pi")
        }
    }

    func menuItemImage(size: CGFloat = 13) -> NSImage? {
        switch self {
        case .claude: NSImage(systemSymbolName: "asterisk", accessibilityDescription: nil)
        case .codex: CodexPromptHexagonIcon.image(size: size)
        case .antigravity: NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)
        case .kiro: KiroGhostIcon.image(size: size)
        case .opencode: OpenCodeBlockRingIcon.image(size: size)
        case .pi: NSImage(systemSymbolName: "pi", accessibilityDescription: nil)
        }
    }
}
