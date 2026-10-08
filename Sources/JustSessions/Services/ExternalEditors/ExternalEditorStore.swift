import AppKit
import Combine

/// The editors from `ExternalEditor.knownEditors` that are installed on this Mac. `ContentView` refreshes it whenever
/// the app comes forward, so an editor installed or removed meanwhile shows up in the menu.
@MainActor
final class ExternalEditorStore: ObservableObject {
    static let shared = ExternalEditorStore()

    @Published private(set) var installedEditors: [InstalledExternalEditor] = []
    private let applicationURLForBundleIdentifier: @MainActor (String) -> URL?
    /// The app that opens links of a URL scheme, such as JetBrains Toolbox for `jetbrains`.
    private let applicationURLForURLScheme: @MainActor (String) -> URL?

    init(
        applicationURLForBundleIdentifier: @escaping @MainActor (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        applicationURLForURLScheme: @escaping @MainActor (String) -> URL? = {
            URL(string: "\($0)://").flatMap(NSWorkspace.shared.urlForApplication(toOpen:))
        }
    ) {
        self.applicationURLForBundleIdentifier = applicationURLForBundleIdentifier
        self.applicationURLForURLScheme = applicationURLForURLScheme
        refresh()
    }

    func refresh() {
        // JetBrains IDEs open SSH projects through Toolbox.
        let opensJetBrainsToolboxLinks = applicationURLForURLScheme(RemoteProjectOpening.jetBrainsToolboxURLScheme) != nil
        var seenApplicationURLs = Set<URL>()
        let foundEditors = ExternalEditor.knownEditors.compactMap { editor -> InstalledExternalEditor? in
            guard
                let applicationURL = editor.bundleIdentifiers.lazy.compactMap(applicationURLForBundleIdentifier).first,
                seenApplicationURLs.insert(applicationURL.standardizedFileURL).inserted
            else { return nil }
            let remoteProjectOpening = editor.remoteProjectOpening.flatMap {
                $0.opensThroughJetBrainsToolbox && !opensJetBrainsToolboxLinks ? nil : $0
            }
            return InstalledExternalEditor(
                name: editor.name,
                applicationURL: applicationURL,
                remoteProjectOpening: remoteProjectOpening
            )
        }
        if foundEditors != installedEditors { installedEditors = foundEditors }
    }

    /// What the project's "Open project in" lists: every installed editor for a folder on this Mac, and those that can
    /// open it over SSH for a folder on an SSH host.
    func editors(for location: ProjectLocation) -> [InstalledExternalEditor] {
        guard case .ssh(let host) = location.host else { return installedEditors }
        return installedEditors.filter { $0.remoteProjectOpening?.link(host: host, path: location.path) != nil }
    }

    /// Opens a folder on this Mac in the editor, or hands a folder on an SSH host to the editor, or to JetBrains
    /// Toolbox, as a link.
    func open(_ location: ProjectLocation, in editor: InstalledExternalEditor) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        guard case .ssh(let host) = location.host else {
            let folderURL = URL(fileURLWithPath: location.path, isDirectory: true)
            _ = try await NSWorkspace.shared.open(
                [folderURL],
                withApplicationAt: editor.applicationURL,
                configuration: configuration
            )
            return
        }
        guard let remoteProjectOpening = editor.remoteProjectOpening,
              let link = remoteProjectOpening.link(host: host, path: location.path) else {
            throw CocoaError(.featureUnsupported)
        }
        if remoteProjectOpening.opensThroughJetBrainsToolbox {
            _ = try await NSWorkspace.shared.open(link, configuration: configuration)
        } else {
            // Straight to this editor, in case another app on this Mac opens the same URL scheme.
            _ = try await NSWorkspace.shared.open([link], withApplicationAt: editor.applicationURL, configuration: configuration)
        }
    }
}
