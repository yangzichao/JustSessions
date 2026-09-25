import Foundation

/// A host and its projects, as the sidebar lists them: hosts in their listed order, each with its projects in the
/// order they were already sorted.
struct HostProjectSection: Identifiable {
    let host: SessionHost
    let projects: [ProjectConversationGroup]

    var id: SessionHost { host }

    /// One section per host, including a host with no projects left after filtering, so its status stays visible.
    static func sections(hosts: [SessionHost], projects: [ProjectConversationGroup]) -> [HostProjectSection] {
        let projectsByHost = Dictionary(grouping: projects, by: \.host)
        return hosts.map { HostProjectSection(host: $0, projects: projectsByHost[$0] ?? []) }
    }
}
