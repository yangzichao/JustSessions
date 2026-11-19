import Foundation
import Testing

@testable import JustSessions

@MainActor
struct FileLinkClickSettingsTests {
    @Test func aFileOpensInItsDefaultAppUntilSomethingElseIsChosen() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        #expect(FileLinkClickSettingsStore(userDefaults: settings.userDefaults).choice == .defaultApp)
    }

    @Test(arguments: [FileLinkClickChoice.askEachTime, .editor(name: "Visual Studio Code"), .defaultApp])
    func theChoiceIsKept(_ choice: FileLinkClickChoice) throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        FileLinkClickSettingsStore(userDefaults: settings.userDefaults).setChoice(.askEachTime)

        FileLinkClickSettingsStore(userDefaults: settings.userDefaults).setChoice(choice)

        #expect(FileLinkClickSettingsStore(userDefaults: settings.userDefaults).choice == choice)
    }

    @Test(arguments: ["", "editor:", "openInVim"])
    func anUnknownSavedValueOpensInTheDefaultApp(_ storedValue: String) throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(storedValue, forKey: FileLinkClickChoice.userDefaultsKey)

        #expect(FileLinkClickSettingsStore(userDefaults: settings.userDefaults).choice == .defaultApp)
    }

    /// Text, a file macOS has no type for, and TypeScript, which macOS takes for video by its `.ts`.
    @Test(arguments: ["plan.md", "main.swift", "package.json", "LICENSE", "Dockerfile", ".env", "index.ts", "notes.zzqx"])
    func aChosenEditorOpensCodeAndText(_ fileName: String) throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent(fileName)
        try Data().write(to: file)

        #expect(FileLinkEditorScope.includes(file))
    }

    @Test(arguments: ["screenshot.png", "report.pdf", "demo.mp4", "archive.zip"])
    func otherFilesStayWithTheirDefaultApp(_ fileName: String) throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent(fileName)
        try Data().write(to: file)

        #expect(!FileLinkEditorScope.includes(file))
    }

    @Test func aPackageStaysWithItsDefaultApp() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let package = folder.appendingPathComponent("Tool.app", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)

        #expect(!FileLinkEditorScope.includes(package))
        #expect(!FileLinkEditorScope.includes(folder.appendingPathComponent("missing.md")))
    }
}
