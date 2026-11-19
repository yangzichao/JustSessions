import AppKit

struct InstalledExternalEditor: Identifiable, Equatable {
    static let menuIconSize = NSSize(width: 16, height: 16)

    let name: String
    let applicationURL: URL
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

    static func == (lhs: InstalledExternalEditor, rhs: InstalledExternalEditor) -> Bool {
        lhs.name == rhs.name && lhs.applicationURL == rhs.applicationURL
            && lhs.sshFolderCommandLineToolURL == rhs.sshFolderCommandLineToolURL
    }
}
