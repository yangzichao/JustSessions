import SwiftUI

/// Feedback sent from the app: a message and an optional email for a reply, sent with the app and macOS versions once
/// Cloudflare Turnstile shows a person wrote it. It opens from General, so it leads with a way back, and ends with
/// email and GitHub for anyone who prefers them.
struct FeedbackSettingsView: View {
    let onShowGeneral: () -> Void
    @Bindable var model: FeedbackFormModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    /// Grows with Try again, which loads the check page anew.
    @State private var verificationPageLoadCount = 0

    private var verificationPageURL: URL {
        FeedbackVerificationPage.url(colorScheme: colorScheme, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onShowGeneral) {
                    Label("General", systemImage: "chevron.left")
                }
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
                .accessibilityIdentifier("feedback.backToGeneral")
                Text("Send feedback").font(.title2.weight(.semibold))
                Text("Tell us what works, what doesn't, and what you'd like next. Only the developer reads it.")
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Message").font(.subheadline.weight(.medium))
                TextEditor(text: $model.message)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(height: 130)
                    .themedTextFieldSurface()
                    .accessibilityLabel("Message")
                    .accessibilityIdentifier("feedback.message")
                if model.isMessageTooLong {
                    FeedbackFieldProblem("Shorten the message to 5,000 characters or fewer.")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Email for a reply (optional)").font(.subheadline.weight(.medium))
                TextField("you@example.com", text: $model.contact)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .textContentType(.emailAddress)
                    .accessibilityLabel("Email for a reply")
                    .accessibilityIdentifier("feedback.contact")
                if model.isContactTooLong {
                    FeedbackFieldProblem("Shorten the email to 200 characters or fewer.")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TurnstileVerificationView(
                        pageURL: verificationPageURL,
                        resetCount: model.verificationResetCount,
                        onEvent: model.verificationChanged
                    )
                    .frame(width: TurnstileVerificationView.size.width, height: TurnstileVerificationView.size.height)
                    .id("\(verificationPageURL.absoluteString)#\(verificationPageLoadCount)")
                    .accessibilityLabel("Spam check")
                    Spacer(minLength: 0)
                    if model.phase == .sending {
                        ProgressView().controlSize(.small)
                    }
                    Button("Send") { Task { await model.send() } }
                        .buttonStyle(ThemeProminentButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!model.canSend)
                        .help("Send feedback (⌘↩)")
                        .accessibilityIdentifier("feedback.send")
                }
                FeedbackStatusLine(phase: model.phase, verification: model.verification) {
                    verificationPageLoadCount += 1
                    model.verificationRestarted()
                }
                Text("Sent with \(model.environment.summary). Kept for up to a year; Cloudflare Turnstile checks that a person sent it.")
                    .font(.caption)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ThemeDivider()
            FeedbackAlternativeLinks(environment: model.environment)
        }
        .foregroundStyle(ThemePalette.ink)
        .onAppear(perform: model.verificationRestarted)
        .onChange(of: verificationPageURL) { model.verificationRestarted() }
        .accessibilityIdentifier("settings.feedback")
    }
}

/// Why a field keeps Send disabled.
private struct FeedbackFieldProblem: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(ThemePalette.errorText)
    }
}
