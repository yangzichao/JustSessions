import AppKit

@MainActor
enum ProjectFolderPanel {
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
