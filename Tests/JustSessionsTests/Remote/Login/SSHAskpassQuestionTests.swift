import Testing

@testable import JustSessions

struct SSHAskpassQuestionTests {
    @Test func aPromptWithoutAHintIsTypedOutOfSight() {
        let question = SSHAskpassQuestion(
            host: "devbox",
            request: SSHAskpassRequest(prompt: "(me@devbox) Password: ", hint: nil),
            context: nil
        )

        #expect(question.kind == .secret)
        #expect(question.prompt == "(me@devbox) Password:")
        #expect(question.answer(typedText: "hunter2") == "hunter2")
    }

    /// OpenSSH asks about a new host key through the askpass program too, with its fingerprint in the prompt.
    @Test func aNewHostKeyIsTrustedWithYes() {
        let prompt = """
            The authenticity of host 'devbox (192.168.252.2)' can't be established.
            ED25519 key fingerprint is: SHA256:gAPlAgQ+Pusjz+Z8+ALT4qF4mWqypJoZKg8zaacDn3U
            This key is not known by any other names.
            Are you sure you want to continue connecting (yes/no/[fingerprint])? 
            """
        let question = SSHAskpassQuestion(host: "devbox", request: SSHAskpassRequest(prompt: prompt, hint: nil), context: nil)

        #expect(question.kind == .unknownHostKey)
        #expect(question.answer(typedText: "ignored") == "yes")
    }

    @Test func theSameSecretAskedAgainWasNotAccepted() {
        let password = SSHAskpassRequest(prompt: "(me@devbox) Password: ", hint: nil)
        let hostKey = SSHAskpassRequest(prompt: "Are you sure you want to continue connecting (yes/no)? ", hint: nil)

        #expect(SSHAskpassQuestion(host: "devbox", request: password, context: nil, previousPrompt: "(me@devbox) Password:").isAskedAgain)
        #expect(!SSHAskpassQuestion(host: "devbox", request: password, context: nil, previousPrompt: "Verification code:").isAskedAgain)
        #expect(!SSHAskpassQuestion(host: "devbox", request: password, context: nil).isAskedAgain)
        #expect(
            !SSHAskpassQuestion(
                host: "devbox",
                request: hostKey,
                context: nil,
                previousPrompt: "Are you sure you want to continue connecting (yes/no)?"
            ).isAskedAgain)
    }

    /// `SSH_ASKPASS_PROMPT` says what kind of question it is.
    @Test func theHintSaysWhenAQuestionNeedsNoTyping() {
        let confirmation = SSHAskpassQuestion(
            host: "devbox",
            request: SSHAskpassRequest(prompt: "Allow use of key?", hint: "confirm"),
            context: nil
        )
        let notice = SSHAskpassQuestion(
            host: "devbox",
            request: SSHAskpassRequest(prompt: "Confirm user presence for key ED25519-SK", hint: "none"),
            context: nil
        )

        #expect(confirmation.kind == .confirmation)
        #expect(confirmation.answer() == "yes")
        #expect(notice.kind == .notice)
    }
}
