import Foundation

struct HostFixAgentDraft: Equatable {
    var machine: HostFixAgentMachine
    var provider: ConversationProvider?
    var task: String
    var guideSections: Set<JustSessionsGuideSection>
}
