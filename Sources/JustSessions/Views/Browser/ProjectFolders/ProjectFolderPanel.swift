import AppKit

/// The system's folder picker, for a project folder on this Mac. Its New Folder button makes a folder for a project
/// that does not exist yet.
@MainActor
enum ProjectFolderPanel {
    /// `prompt` names the panel's default button. Opens in `startingFolder` when it exists, and calls `onChoose` with
    /// the path of the folder picked.
    static func choose(
        prompt: String,
        startingAt startingFolder: String? = nil,
        onChoose: @escaping (String) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        if let startingFolder, FileManager.default.fileExists(atPath: startingFolder) {
            panel.directoryURL = URL(fileURLWithPath: startingFolder)
        }
        panel.begin { response in
            if response == .OK, let chosenFolder = panel.url {
                onChoose(chosenFolder.path)
            }
        }
    }
}
