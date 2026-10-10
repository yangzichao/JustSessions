import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ExternalEditorStoreTests {
    @Test func listsOnlyInstalledEditorsInCatalogOrder() {
        let installedApplications = [
            "dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app"),
            "com.microsoft.VSCode": URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
            "com.jetbrains.intellij": URL(fileURLWithPath: "/Users/me/Applications/IntelliJ IDEA Ultimate.app"),
        ]
        let editorStore = ExternalEditorStore { installedApplications[$0] }

        #expect(editorStore.installedEditors.map(\.name) == ["IntelliJ IDEA", "Visual Studio Code", "Zed"])
        #expect(editorStore.installedEditors.map(\.applicationURL.lastPathComponent) == [
            "IntelliJ IDEA Ultimate.app", "Visual Studio Code.app", "Zed.app",
        ])
    }

    @Test func prefersTheNewestBundleIdentifierAndListsEachAppOnce() {
        let sublimeText3 = URL(fileURLWithPath: "/Applications/Sublime Text 3.app")
        let sublimeText4 = URL(fileURLWithPath: "/Applications/Sublime Text.app")
        let vscodium = URL(fileURLWithPath: "/Applications/VSCodium.app")
        let installedApplications = [
            "com.sublimetext.3": sublimeText3,
            "com.sublimetext.4": sublimeText4,
            // An app answering to two catalog entries' identifiers is listed once, under the first entry.
            "com.vscodium": vscodium,
            "com.microsoft.VSCodeInsiders": vscodium,
        ]
        let editorStore = ExternalEditorStore { installedApplications[$0] }

        #expect(editorStore.installedEditors.map(\.name) == ["Sublime Text", "Visual Studio Code Insiders"])
        #expect(editorStore.installedEditors.map(\.applicationURL) == [sublimeText4, vscodium])
    }

    @Test func refreshPicksUpEditorsInstalledLater() {
        var installedApplications: [String: URL] = [:]
        let editorStore = ExternalEditorStore { installedApplications[$0] }
        #expect(editorStore.installedEditors.isEmpty)

        installedApplications["com.todesktop.230313mzl4w4u92"] = URL(fileURLWithPath: "/Applications/Cursor.app")
        editorStore.refresh()
        #expect(editorStore.installedEditors.map(\.name) == ["Cursor"])
    }

    @Test func offersOnlyEditorsWithAnSSHToolForSSHFolders() {
        let vscode = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        let zed = URL(fileURLWithPath: "/Applications/Zed.app")
        let codeTool = vscode.appendingPathComponent("Contents/Resources/app/bin/code")
        let installedApplications = ["com.microsoft.VSCode": vscode, "dev.zed.Zed": zed]
        let editorStore = ExternalEditorStore(
            applicationURLForBundleIdentifier: { installedApplications[$0] },
            sshFolderCommandLineToolForApplication: { $0 == vscode ? codeTool : nil }
        )

        #expect(editorStore.editors(opening: .thisMac).map(\.name) == ["Visual Studio Code", "Zed"])
        #expect(editorStore.editors(opening: .ssh("devbox")).map(\.name) == ["Visual Studio Code"])
        #expect(editorStore.editors(opening: .ssh("devbox")).first?.sshFolderCommandLineToolURL == codeTool)
    }

    @Test func catalogNamesAndBundleIdentifiersAreUnique() {
        let names = ExternalEditor.knownEditors.map(\.name)
        let bundleIdentifiers = ExternalEditor.knownEditors.flatMap(\.bundleIdentifiers)
        #expect(Set(names).count == names.count)
        #expect(Set(bundleIdentifiers).count == bundleIdentifiers.count)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }
}
