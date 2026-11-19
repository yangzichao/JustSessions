import Foundation

struct SeveralTabsClosingRequest: Identifiable, Equatable, Sendable {
    enum Subject: Equatable, Sendable {
        case group(projectName: String)
        case selectedTabs
    }

    let id = UUID()
    let subject: Subject
    let tabIDs: [UUID]
    let question: SeveralTabsClosingQuestion
}
