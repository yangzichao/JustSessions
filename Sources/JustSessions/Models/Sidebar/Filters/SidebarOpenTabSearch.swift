import Foundation

enum SidebarOpenTabSearch {
    static func matches(
        _ query: String,
        title: String,
        projectName: String,
        projectPath: String,
        host: SessionHost
    ) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [title, projectName, projectPath, host.sshDestination ?? ""]
            .contains { $0.localizedStandardContains(query) }
    }
}
