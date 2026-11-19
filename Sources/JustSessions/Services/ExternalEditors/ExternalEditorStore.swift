import AppKit
import Combine

@MainActor
final class ExternalEditorStore: ObservableObject {
    static let shared = ExternalEditorStore()

    @Published private(set) var installedEditors: [InstalledExternalEditor] = []
    private let applicationURLForBundleIdentifier: @MainActor (String) -> URL?
    private let sshFolderCommandLineToolForApplication: @MainActor (URL) -> URL?

    init(
        applicationURLForBundleIdentifier: @escaping @MainActor (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        sshFolderCommandLineToolForApplication: @escaping @MainActor (URL) -> URL? = {
            RemoteSSHCommandLineTool.find(inApplicationAt: $0)
        }
    ) {
        self.applicationURLForBundleIdentifier = applicationURLForBundleIdentifier
        self.sshFolderCommandLineToolForApplication = sshFolderCommandLineToolForApplication
        refresh()
    }

    func refresh() {
        var seenApplicationURLs = Set<URL>()
        let foundEditors = ExternalEditor.knownEditors.compactMap { editor -> InstalledExternalEditor? in
            guard
                let applicationURL = editor.bundleIdentifiers.lazy.compactMap(applicationURLForBundleIdentifier).first,
                seenApplicationURLs.insert(applicationURL.standardizedFileURL).inserted
            else { return nil }
            return InstalledExternalEditor(
                name: editor.name,
                applicationURL: applicationURL,
                sshFolderCommandLineToolURL: sshFolderCommandLineToolForApplication(applicationURL)
            )
        }
        if foundEditors != installedEditors { installedEditors = foundEditors }
    }

    func editors(opening host: SessionHost) -> [InstalledExternalEditor] {
        switch host {
        case .thisMac: installedEditors
        case .ssh: installedEditors.filter { $0.sshFolderCommandLineToolURL != nil }
        }
    }

    func open(_ location: ProjectLocation, in editor: InstalledExternalEditor) async throws {
        switch location.host {
        case .thisMac:
            let folderURL = URL(fileURLWithPath: location.path, isDirectory: true)
            _ = try await NSWorkspace.shared.open(
                [folderURL],
                withApplicationAt: editor.applicationURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        case .ssh(let destination):
            guard let toolURL = editor.sshFolderCommandLineToolURL else {
                throw RemoteSSHFolderOpenError.editorCannotOpenSSHFolders
            }
            try await RemoteSSHFolderOpener.open(path: location.path, on: destination, withCommandLineToolAt: toolURL)
        }
    }
}
