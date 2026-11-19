import Foundation

struct SessionsDeletedWhenTabCloses: Equatable {
    static let userDefaultsKey = "conversationIDsDeletedWhenTabCloses"

    private(set) var conversationIDs: Set<String>

    init(conversationIDs: Set<String> = []) {
        self.conversationIDs = conversationIDs
    }

    static func load(from userDefaults: UserDefaults) -> SessionsDeletedWhenTabCloses {
        SessionsDeletedWhenTabCloses(conversationIDs: Set(userDefaults.stringArray(forKey: userDefaultsKey) ?? []))
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(conversationIDs.sorted(), forKey: Self.userDefaultsKey)
    }

    func isDeletedWhenTabCloses(conversationID: String) -> Bool {
        conversationIDs.contains(conversationID)
    }

    mutating func setDeletedWhenTabCloses(_ isDeleted: Bool, conversationIDs changedIDs: some Sequence<String>) {
        if isDeleted {
            conversationIDs.formUnion(changedIDs)
        } else {
            conversationIDs.subtract(changedIDs)
        }
    }
}
