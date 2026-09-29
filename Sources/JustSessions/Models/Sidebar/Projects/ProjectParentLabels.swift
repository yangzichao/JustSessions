import Foundation

/// Projects on one host that share a display name also show their parent folders, so their rows can be told apart.
/// The same name on two hosts needs nothing, since the host headings already tell those projects apart.
struct ProjectParentLabels {
    private let labelsByProjectID: [String: String]

    init(projectsOnOneHost projects: [ProjectConversationGroup]) {
        let repeatedNames = Set(Dictionary(grouping: projects, by: \.displayName)
            .filter { $0.value.count > 1 }
            .map(\.key))
        labelsByProjectID = Dictionary(
            projects
                .filter { repeatedNames.contains($0.displayName) }
                .map { ($0.id, Self.parentLabel(forFolderPath: $0.location.path)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Nil for a project whose name no other project on the host has.
    func label(for project: ProjectConversationGroup) -> String? {
        labelsByProjectID[project.id]
    }

    /// The last two folders above the project, such as `code/work` for `/Users/me/code/work/app`, or `/` for a
    /// project at the top of the disk.
    static func parentLabel(forFolderPath folderPath: String) -> String {
        let parentFolders = URL(fileURLWithPath: folderPath).deletingLastPathComponent().pathComponents
            .filter { $0 != "/" }
        return parentFolders.isEmpty ? "/" : parentFolders.suffix(2).joined(separator: "/")
    }
}
