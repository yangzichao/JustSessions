import SwiftUI

struct SSHLoginQuestionSheet: View {
    let question: SSHAskpassQuestion
    let onAnswer: (String?) -> Void
    @State private var typedText = ""
    @FocusState private var isAnswerFocused: Bool

    var body: some View {
        ThemeSheetLayout(title: title, intro: intro, width: ThemeSheetMetrics.compactWidth) {
            VStack(alignment: .leading, spacing: 8) {
                if let context = question.context {
                    sshText(context)
                }
                if question.isAskedAgain {
                    Text("That answer wasn't accepted. Try again.")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.warningText)
                }
                if !question.prompt.isEmpty {
                    sshText(question.prompt)
                }
                switch question.kind {
                case .secret:
                    SecureField("Answer", text: $typedText)
                        .textFieldStyle(ThemedTextFieldStyle())
                        .accessibilityLabel(Text(verbatim: question.prompt))
                        .focused($isAnswerFocused)
                        .onAppear { isAnswerFocused = true }
                        .onSubmit(answer)
                case .notice:
                    ProgressView().controlSize(.small)
                case .unknownHostKey, .confirmation:
                    EmptyView()
                }
            }
        } footer: {
            Spacer()
            Button("Cancel") { onAnswer(nil) }
                .keyboardShortcut(.cancelAction)
            if question.kind != .notice {
                Button(answerButtonTitle, action: answer)
                    .buttonStyle(ThemeProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var title: Text {
        if question.asker == .signInCommand { return Text("Sign in on \(question.host)") }
        return question.kind == .unknownHostKey ? Text("Trust \(question.host)?") : Text("Log in to \(question.host)")
    }

    private var intro: Text {
        if question.asker == .signInCommand {
            return Text("Your sign-in command asks this on \(question.host). JustSessions keeps nothing you type.")
        }
        switch question.kind {
        case .unknownHostKey:
            return Text("This Mac hasn't connected to this host before. Trust it only if the fingerprint matches the host's.")
        case .secret, .confirmation, .notice:
            return Text("`ssh` asks this to log in. JustSessions keeps nothing you type.")
        }
    }

    private var answerButtonTitle: LocalizedStringKey {
        switch question.kind {
        case .unknownHostKey: "Trust and connect"
        case .confirmation: "Yes"
        case .secret, .notice: "Continue"
        }
    }

    private func sshText(_ text: String) -> some View {
        Text(verbatim: text)
            .font(ThemeFont.callout.monospaced())
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answer() {
        onAnswer(question.answer(typedText: typedText))
    }
}
