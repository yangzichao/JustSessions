import Foundation

/// Feedback written in Settings, as the Worker receives it: the message, an email for a reply when one is given, the
/// versions it is about, and the Turnstile token that shows a person sent it.
struct FeedbackSubmission: Encodable, Equatable {
    let message: String
    let contact: String?
    let appVersion: String
    let macOSVersion: String
    let turnstileToken: String

    init(message: String, contact: String, environment: FeedbackEnvironment, turnstileToken: String) {
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contact = trimmedContact.isEmpty ? nil : trimmedContact
        appVersion = environment.appVersion
        macOSVersion = environment.macOSVersion
        self.turnstileToken = turnstileToken
    }

    private enum CodingKeys: String, CodingKey {
        case message, contact, source, appVersion, macOSVersion, turnstileToken
    }

    /// The Worker refuses a `null` contact, so a missing one is left out.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(contact, forKey: .contact)
        try container.encode("app", forKey: .source)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(macOSVersion, forKey: .macOSVersion)
        try container.encode(turnstileToken, forKey: .turnstileToken)
    }
}
