import Foundation

struct HostProjectSection: Identifiable {
    let host: SessionHost
    let projects: [ProjectConversationGroup]

    var id: SessionHost { host }

    static func sections(hosts: [SessionHost], projects: [ProjectConversationGroup]) -> [HostProjectSection] {
        let projectsByHost = Dictionary(grouping: projects, by: \.host)
        return hosts.map { HostProjectSection(host: $0, projects: projectsByHost[$0] ?? []) }
    }
}
