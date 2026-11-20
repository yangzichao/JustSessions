import AppKit

struct InstalledExternalEditor: Identifiable, Equatable {
    static let menuIconSize = NSSize(width: 16, height: 16)

    let name: String
    let applicationURL: URL
    let vsCodeFamilyCommandLineToolURL: URL?
    let icon: NSImage

    var id: URL { applicationURL }

    init(name: String, applicationURL: URL, vsCodeFamilyCommandLineToolURL: URL? = nil) {
        self.name = name
        self.applicationURL = applicationURL
        self.vsCodeFamilyCommandLineToolURL = vsCodeFamilyCommandLineToolURL
        icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.size = Self.menuIconSize
    }

    static func == (lhs: InstalledExternalEditor, rhs: InstalledExternalEditor) -> Bool {
        lhs.name == rhs.name && lhs.applicationURL == rhs.applicationURL
            && lhs.vsCodeFamilyCommandLineToolURL == rhs.vsCodeFamilyCommandLineToolURL
    }
}
