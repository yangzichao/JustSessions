import AppKit
import Combine

/// The editors from `ExternalEditor.knownEditors` that are installed on this Mac. `ContentView` refreshes it whenever
/// the app comes forward, so an editor installed or removed meanwhile shows up in the menu.
@MainActor
final class ExternalEditorStore: ObservableObject {
    static let shared = ExternalEditorStore()

    @Published private(set) var installedEditors: [InstalledExternalEditor] = []
    private let applicationURLForBundleIdentifier: @MainActor (String) -> URL?

    init(
        applicationURLForBundleIdentifier: @escaping @MainActor (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
    ) {
        self.applicationURLForBundleIdentifier = applicationURLForBundleIdentifier
        refresh()
    }

    func refresh() {
        var seenApplicationURLs = Set<URL>()
        let foundEditors = ExternalEditor.knownEditors.compactMap { editor -> InstalledExternalEditor? in
            guard
                let applicationURL = editor.bundleIdentifiers.lazy.compactMap(applicationURLForBundleIdentifier).first,
                seenApplicationURLs.insert(applicationURL.standardizedFileURL).inserted
            else { return nil }
            return InstalledExternalEditor(name: editor.name, applicationURL: applicationURL)
        }
        if foundEditors != installedEditors { installedEditors = foundEditors }
    }

    func open(folderPath: String, in editor: InstalledExternalEditor) async throws {
        let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        _ = try await NSWorkspace.shared.open(
            [folderURL],
            withApplicationAt: editor.applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
