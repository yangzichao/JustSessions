import AppKit

/// An editor from `ExternalEditor.knownEditors` that is installed on this Mac, with its menu-sized app icon.
struct InstalledExternalEditor: Identifiable, Equatable {
    static let menuIconSize = NSSize(width: 16, height: 16)

    let name: String
    let applicationURL: URL
    /// Nil when the editor can't open a project on an SSH host from this Mac.
    let remoteProjectOpening: RemoteProjectOpening?
    let icon: NSImage

    var id: URL { applicationURL }

    init(name: String, applicationURL: URL, remoteProjectOpening: RemoteProjectOpening? = nil) {
        self.name = name
        self.applicationURL = applicationURL
        self.remoteProjectOpening = remoteProjectOpening
        icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.size = Self.menuIconSize
    }

    /// The icon is derived from the app, so two entries for the same app are equal.
    static func == (lhs: InstalledExternalEditor, rhs: InstalledExternalEditor) -> Bool {
        lhs.name == rhs.name && lhs.applicationURL == rhs.applicationURL
            && lhs.remoteProjectOpening == rhs.remoteProjectOpening
    }
}
