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

    @Test func listsOnlyEditorsThatOpenProjectsOverSSHForAProjectOnAHost() {
        let editorStore = ExternalEditorStore(
            applicationURLForBundleIdentifier: { Self.installedForRemoteTests[$0] },
            applicationURLForURLScheme: { $0 == "jetbrains" ? URL(fileURLWithPath: "/Applications/JetBrains Toolbox.app") : nil }
        )
        let remoteProject = ProjectLocation(host: .ssh("jryates@max"), path: "/home/jryates/app")
        let localProject = ProjectLocation(host: .thisMac, path: "/Users/me/app")

        #expect(editorStore.editors(for: remoteProject).map(\.name) == ["Antigravity IDE", "GoLand", "Zed"])
        #expect(editorStore.editors(for: localProject).map(\.name) == [
            "Antigravity", "Antigravity IDE", "GoLand", "IntelliJ IDEA CE", "Sublime Text", "Xcode", "Zed",
        ])
        // Zed's link can't name this host; Antigravity IDE's can.
        let oddHostProject = ProjectLocation(host: .ssh("my,host"), path: "/srv")
        #expect(editorStore.editors(for: oddHostProject).map(\.name) == ["Antigravity IDE", "GoLand"])
    }

    @Test func jetBrainsIDEsOpenNoSSHProjectWithoutJetBrainsToolbox() {
        let editorStore = ExternalEditorStore(
            applicationURLForBundleIdentifier: { Self.installedForRemoteTests[$0] },
            applicationURLForURLScheme: { _ in nil }
        )
        let remoteProject = ProjectLocation(host: .ssh("max"), path: "/srv")

        #expect(editorStore.editors(for: remoteProject).map(\.name) == ["Antigravity IDE", "Zed"])
        #expect(editorStore.installedEditors.first { $0.name == "GoLand" }?.remoteProjectOpening == nil)
    }

    private static let installedForRemoteTests = [
        "com.google.antigravity": URL(fileURLWithPath: "/Applications/Antigravity.app"),
        "com.google.antigravity-ide": URL(fileURLWithPath: "/Applications/Antigravity IDE.app"),
        "com.jetbrains.goland": URL(fileURLWithPath: "/Users/me/Applications/GoLand.app"),
        "com.jetbrains.intellij.ce": URL(fileURLWithPath: "/Applications/IntelliJ IDEA CE.app"),
        "com.sublimetext.4": URL(fileURLWithPath: "/Applications/Sublime Text.app"),
        "com.apple.dt.Xcode": URL(fileURLWithPath: "/Applications/Xcode.app"),
        "dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app"),
    ]

    @Test func catalogNamesAndBundleIdentifiersAreUnique() {
        let names = ExternalEditor.knownEditors.map(\.name)
        let bundleIdentifiers = ExternalEditor.knownEditors.flatMap(\.bundleIdentifiers)
        #expect(Set(names).count == names.count)
        #expect(Set(bundleIdentifiers).count == bundleIdentifiers.count)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }
}
