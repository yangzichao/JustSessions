import AppKit

/// An editor from `ExternalEditor.knownEditors` that is installed on this Mac, with its menu-sized app icon.
struct InstalledExternalEditor: Identifiable, Equatable {
    static let menuIconSize = NSSize(width: 16, height: 16)

    let name: String
    let applicationURL: URL
    /// The tool that opens a folder on an SSH host in this editor; nil when it can't. See `RemoteSSHCommandLineTool`.
    let sshFolderCommandLineToolURL: URL?
    let icon: NSImage

    var id: URL { applicationURL }

    init(name: String, applicationURL: URL, sshFolderCommandLineToolURL: URL? = nil) {
        self.name = name
        self.applicationURL = applicationURL
        self.sshFolderCommandLineToolURL = sshFolderCommandLineToolURL
        icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.size = Self.menuIconSize
    }

    /// The icon is derived from the app, so two entries for the same app are equal.
    static func == (lhs: InstalledExternalEditor, rhs: InstalledExternalEditor) -> Bool {
        lhs.name == rhs.name && lhs.applicationURL == rhs.applicationURL
            && lhs.sshFolderCommandLineToolURL == rhs.sshFolderCommandLineToolURL
    }
}
