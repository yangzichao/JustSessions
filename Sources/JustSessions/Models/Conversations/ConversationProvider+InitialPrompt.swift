import Foundation

extension ConversationProvider {
    func initialPromptArguments(_ prompt: String) -> [String] {
        // A leading `-` would read as an option, and Pi reads a leading `@` as a file to attach.
        let promptArgument = prompt.hasPrefix("-") || prompt.hasPrefix("@") ? " " + prompt : prompt
        switch self {
        case .claude, .codex, .pi: return [promptArgument]
        case .kiro: return ["chat", promptArgument]
        case .opencode: return ["--prompt", promptArgument]
        case .antigravity: return ["--prompt-interactive", promptArgument]
        }
    }
}
