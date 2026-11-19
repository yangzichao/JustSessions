import Foundation

struct ProjectParentLabels {
    private let labelsByProjectID: [String: String]

    init(projectsOnOneHost projects: [ProjectConversationGroup]) {
        let repeatedNames = Set(
            Dictionary(grouping: projects, by: \.displayName)
                .filter { $0.value.count > 1 }
                .map(\.key))
        labelsByProjectID = Dictionary(
            projects
                .filter { repeatedNames.contains($0.displayName) }
                .map { ($0.id, Self.parentLabel(forFolderPath: $0.location.path)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func label(for project: ProjectConversationGroup) -> String? {
        labelsByProjectID[project.id]
    }

    /// The last two folders above the project, such as `code/work` for `/Users/me/code/work/app`, or `/` for a
    /// project at the top of the disk. Works on the text alone: `URL(fileURLWithPath:)` asks this Mac's disk whether
    /// the path is a folder, and an SSH host's `/home/...` path there is an automount lookup of 15 to 150 ms.
    static func parentLabel(forFolderPath folderPath: String) -> String {
        let parentFolders = ((folderPath as NSString).deletingLastPathComponent as NSString).pathComponents
            .filter { $0 != "/" }
        return parentFolders.isEmpty ? "/" : parentFolders.suffix(2).joined(separator: "/")
    }
}
