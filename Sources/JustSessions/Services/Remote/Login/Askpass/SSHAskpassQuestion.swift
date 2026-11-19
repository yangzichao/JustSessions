import Foundation

struct SSHAskpassQuestion: Identifiable, Equatable, Sendable {
    enum Asker: Equatable, Sendable {
        case ssh
        case signInCommand
    }

    enum Kind: Equatable, Sendable {
        case secret
        case unknownHostKey
        /// A yes or no question. `ssh` takes "yes", or the helper failing as no.
        case confirmation
        /// Something to do with no answer, such as touching a security key; `ssh` ends the helper when it is done.
        case notice
    }

    let id = UUID()
    let host: String
    let asker: Asker
    let kind: Kind
    let prompt: String
    let context: String?
    /// Whether `ssh` asks the secret it asked last again, which means it did not accept the answer. A refused
    /// keyboard-interactive answer is asked again with nothing printed, so this is the only sign of it.
    let isAskedAgain: Bool

    init(host: String, request: SSHAskpassRequest, context: String?, previousPrompt: String? = nil) {
        self.host = host
        asker = .ssh
        prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.context = context
        kind =
            switch request.hint {
            case "confirm": .confirmation
            case "none": .notice
            default: Self.asksToTrustHostKey(request.prompt) ? .unknownHostKey : .secret
            }
        isAskedAgain = kind == .secret && prompt == previousPrompt
    }

    init(signInOn host: String, prompt: String, context: String?, previousPrompt: String?) {
        self.host = host
        asker = .signInCommand
        kind = .secret
        self.prompt = prompt
        self.context = context
        isAskedAgain = prompt == previousPrompt
    }

    /// OpenSSH asks "Are you sure you want to continue connecting (yes/no/[fingerprint])?" about a new host key.
    static func asksToTrustHostKey(_ prompt: String) -> Bool {
        prompt.lowercased().contains("continue connecting (yes/no")
    }

    func answer(typedText: String = "") -> String {
        switch kind {
        case .secret: typedText
        case .unknownHostKey, .confirmation: "yes"
        case .notice: ""
        }
    }
}
