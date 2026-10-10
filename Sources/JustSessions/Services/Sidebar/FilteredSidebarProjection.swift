import Foundation

/// The projects and filter-bar counts the browser shows for one combination of its tool, recency, status, and search
/// filters, with the sessions a search found in messages. The browser re-renders on every keystroke, click, and poll tick, and filtering a few thousand sessions
/// takes milliseconds, so the store keeps the last answer until one of `Inputs` changes.
struct FilteredSidebarProjection {
    struct Inputs: Equatable {
        let projectionInputs: SidebarProjection.Inputs
        let titleAliases: ConversationTitleAliases
        let providerFilter: ConversationProviderFilter
        let recencyFilter: SessionRecencyFilter
        let statusFilter: SessionStatusFilter
        /// Kept whatever the status filter, for the filter bar's counts.
        let running: SessionsRunning
        let waiting: SessionsWaitingForYou
        let searchText: String
        /// Sessions whose messages hold the search text, listed along with those whose title or ID does.
        let messageMatchConversationIDs: Set<String>
        /// `Date.now` rounded down to the minute. The Recent filter classifies against the current time, so the
        /// time belongs to the inputs; minute precision re-classifies an aging session at most a minute late
        /// without making every render a cache miss.
        let recencyNow: Date
    }

    let inputs: Inputs
    /// Narrowed by the tool, recency, and search filters, in sidebar order.
    let projects: [ProjectConversationGroup]
    /// The tool filter's sessions before the recency filter: the filter bar's "All" count.
    let allSessionCount: Int
    /// Those of `allSessionCount`'s sessions the Recent filter keeps: the filter bar's "Recent" count.
    let recentSessionCount: Int
    /// Those of `allSessionCount`'s sessions whose CLI runs: the filter bar's "Running" count.
    let runningSessionCount: Int
    /// Those of `allSessionCount`'s sessions whose CLI waits on you: the filter bar's "Waiting for you" count.
    let waitingSessionCount: Int

    init(inputs: Inputs, projection: SidebarProjection, title: (Conversation) -> String) {
        self.inputs = inputs
        let providerConversations = projection.conversations.filter { inputs.providerFilter.includes($0.provider) }
        allSessionCount = providerConversations.count
        recentSessionCount = providerConversations
            .filter { SessionRecencyFilter.recent.includes($0, now: inputs.recencyNow) }
            .count
        runningSessionCount = providerConversations.filter { inputs.running.conversationIDs.contains($0.id) }.count
        waitingSessionCount = providerConversations.filter { inputs.waiting.conversationIDs.contains($0.id) }.count
        let filteredProjects = SidebarProjectFiltering.projects(
            projection.projectGroups,
            providerFilter: inputs.providerFilter,
            recencyFilter: inputs.recencyFilter,
            statusFilter: inputs.statusFilter,
            running: inputs.running,
            waiting: inputs.waiting,
            now: inputs.recencyNow
        )
        projects = SidebarProjectFiltering.projects(
            filteredProjects,
            matching: inputs.searchText,
            title: title,
            messageMatchConversationIDs: inputs.messageMatchConversationIDs
        )
    }
}
