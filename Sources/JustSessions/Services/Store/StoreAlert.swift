import Foundation

/// What the main window's alert shows: a title, a message, and, after a deletion that may work a second time, the
/// sessions Try Again deletes. Each alert is told apart by `id`, so dismissing one never dismisses a newer one.
struct StoreAlert: Identifiable, Equatable, Sendable {
    /// The title of an alert that is not about a particular action.
    static let defaultTitle = "Could not complete action"

    let id = UUID()
    let title: String
    let message: String
    /// The sessions, by `Conversation.id`, that were not deleted for a reason that may pass, such as a lost
    /// connection. Empty when trying again would not help, and then Try Again is not offered.
    var retryConversationIDs: Set<String> = []

    var offersTryAgain: Bool { !retryConversationIDs.isEmpty }
}
