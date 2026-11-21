import Foundation

enum SidebarSearchScope: String, CaseIterable {
    case everything = "everything"
    case namesOnly = "namesOnly"

    static let userDefaultsKey = "sidebarSearchScope"

    var searchesMessagesAndBookmarks: Bool {
        self == .everything
    }

    func messageSearchQuery(typedQuery: String) -> String {
        searchesMessagesAndBookmarks ? typedQuery : ""
    }
}
