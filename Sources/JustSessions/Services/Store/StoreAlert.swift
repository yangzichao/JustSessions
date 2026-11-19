import Foundation

struct StoreAlert: Identifiable, Equatable, Sendable {
    static let defaultTitle = "Could not complete action"

    let id = UUID()
    let title: String
    let message: String
    var retryConversationIDs: Set<String> = []

    var offersTryAgain: Bool { !retryConversationIDs.isEmpty }
}
